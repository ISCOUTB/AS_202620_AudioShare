import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/live_audio_engine.dart';

/// Debe coincidir con PROTOCOL_VERSION de web/audioshare_live.js.
const _protocolVersion = 1;
const _headerBytes = 20;
const _sampleRate = 48000;
const _channels = 2;
const _framesPerPacket = 1024;

const _control = MethodChannel('audioshare/capture');
const _pcm = EventChannel('audioshare/capture/pcm');

LiveAudioEngine createLiveAudioEngine() =>
    Platform.isAndroid ? AndroidLiveAudioEngine() : UnsupportedLiveAudioEngine();

Future<void> preloadLiveAudio() async {}

class AndroidLiveAudioEngine implements LiveAudioEngine {
  final _events = StreamController<LiveEngineEvent>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _pcmSub;
  Timer? _statsTimer;
  int _sequence = 0;
  int _sent = 0;
  double _offsetMs = 0;
  bool _emitting = false;

  static const _receiveReason =
      'Escuchar en vivo desde la app de Android todavía no está disponible. '
      'Abre AudioShare en el navegador del celular para escuchar.';

  @override
  List<CaptureOption> get captureOptions => const [
        CaptureOption(source: CaptureSource.device, available: true),
        CaptureOption(
          source: CaptureSource.app,
          available: false,
          reason: 'Compartir el audio de una sola app todavía no está disponible en Android.',
        ),
      ];

  @override
  bool get canReceive => false;

  @override
  Stream<LiveEngineEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> prepareReceiver() async {}

  @override
  Future<bool> unlock() async => false;

  @override
  Future<void> startEmitting({
    required Uri url,
    required String emitterKey,
    required CaptureSource source,
    required double offsetMs,
  }) async {
    if (source != CaptureSource.device) {
      throw const LiveEngineException('Ese origen todavía no está disponible en Android.');
    }
    await stopEmitting();
    _offsetMs = offsetMs;
    _sequence = 0;
    _sent = 0;
    _events.add(const LiveStateEvent(LiveLinkState.connecting));

    final wsUrl = url.replace(
      scheme: switch (url.scheme) { 'https' => 'wss', 'http' => 'ws', final s => s },
    );

    // 1. Conectar con la sala.
    final WebSocket socket;
    try {
      socket = await WebSocket.connect(wsUrl.toString()).timeout(const Duration(seconds: 10));
    } catch (_) {
      _events.add(const LiveStateEvent(LiveLinkState.idle));
      throw const LiveEngineException('No se pudo conectar con la sala. ¿Está el celular en la misma red?');
    }
    _socket = socket;

    // 2. hello -> esperar el «ready» del servidor (igual que audioshare_live.js).
    final ready = Completer<void>();
    socket.listen(
      (message) {
        if (message is! String) return;
        try {
          final data = jsonDecode(message);
          if (data is Map && data['type'] == 'ready' && !ready.isCompleted) ready.complete();
        } catch (_) {
          // Mensaje de control mal formado: se ignora.
        }
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(LiveEngineException(
            'La sala rechazó la conexión (código ${socket.closeCode}). Revisa que la sala siga abierta.',
          ));
        } else {
          _lost('Se cerró la conexión con la sala.');
        }
      },
      onError: (Object _) {
        if (!ready.isCompleted) {
          ready.completeError(const LiveEngineException('Se perdió la conexión con la sala.'));
        } else {
          _lost('Se perdió la conexión con la sala.');
        }
      },
    );
    socket.add(jsonEncode({'type': 'hello', 'role': 'emitter', 'key': emitterKey}));

    try {
      await ready.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const LiveEngineException('La sala no respondió a tiempo.'),
      );

      // 3. Pedir permisos y arrancar la captura (el PCM llega por el EventChannel).
      _pcmSub = _pcm.receiveBroadcastStream().listen(
        _onChunk,
        onError: (Object e) => _lost(e is PlatformException ? (e.message ?? 'Falló la captura.') : '$e'),
      );
      await _control.invokeMethod<void>('start');
    } on PlatformException catch (e) {
      await _teardown();
      _events.add(const LiveStateEvent(LiveLinkState.idle));
      throw LiveEngineException(e.message ?? 'No se pudo iniciar la captura de audio.');
    } on LiveEngineException {
      await _teardown();
      _events.add(const LiveStateEvent(LiveLinkState.idle));
      rethrow;
    }

    // 4. Avisar a los receptores y empezar a enviar paquetes.
    _emitting = true;
    socket.add(jsonEncode({
      'type': 'live.start',
      'source': CaptureSource.device.name,
      'label': CaptureSource.device.title,
    }));
    _events.add(LiveStateEvent(
      LiveLinkState.sharing,
      source: CaptureSource.device.name,
      label: CaptureSource.device.title,
    ));
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _events.add(LiveStatsEvent(sent: _sent, dropped: 0));
    });
  }

  void _onChunk(dynamic data) {
    final socket = _socket;
    if (!_emitting || socket == null || data is! Uint8List) return;
    const chunkMs = _framesPerPacket * 1000 / _sampleRate;
    final captureMs = DateTime.now().millisecondsSinceEpoch + _offsetMs - chunkMs;

    final packet = Uint8List(_headerBytes + data.length);
    final view = ByteData.sublistView(packet);
    view.setUint8(0, _protocolVersion);
    view.setUint8(1, 0); // códec 0 = PCM16
    view.setUint8(2, _channels);
    view.setUint8(3, 0);
    view.setUint32(4, _sampleRate, Endian.little);
    view.setUint32(8, _sequence++ & 0xFFFFFFFF, Endian.little);
    view.setFloat64(12, captureMs, Endian.little);
    packet.setRange(_headerBytes, packet.length, data);
    socket.add(packet);
    _sent++;
  }

  void _lost(String message) {
    if (!_emitting && _socket == null) return;
    _teardown();
    _events.add(LiveStateEvent(LiveLinkState.error, message: message));
  }

  Future<void> _teardown() async {
    final socket = _socket;
    if (_emitting && socket != null) {
      try { socket.add(jsonEncode({'type': 'live.stop'})); } catch (_) {}
    }
    _emitting = false;
    _statsTimer?.cancel();
    _statsTimer = null;
    await _pcmSub?.cancel();
    _pcmSub = null;
    try { await _control.invokeMethod<void>('stop'); } catch (_) {}
    _socket = null;
    try { await socket?.close(1000); } catch (_) {}
  }

  @override
  Future<void> stopEmitting() async {
    final wasActive = _emitting || _socket != null;
    await _teardown();
    if (wasActive) _events.add(const LiveStateEvent(LiveLinkState.idle));
  }

  @override
  void startReceiving({
    required Uri url,
    required String receiverId,
    required double offsetMs,
    int delayMs = 400,
  }) {
    _events.add(const LiveStateEvent(LiveLinkState.error, message: _receiveReason));
  }

  @override
  void stopReceiving() {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> dispose() async {
    await _teardown();
    await _events.close();
  }
}
