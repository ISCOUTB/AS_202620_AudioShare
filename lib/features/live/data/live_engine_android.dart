import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/live_audio_engine.dart';

/// Debe coincidir con PROTOCOL_VERSION de web/audioshare_live.js.
const _protocolVersion = 1;
const _headerBytes = 20;
const _sampleRate = 48000;
const _channels = 2;
const _framesPerPacket = 1024;
const _playback = MethodChannel('audioshare/playback');

const _control = MethodChannel('audioshare/capture');
const _pcm = EventChannel('audioshare/capture/pcm');
const _playback = MethodChannel('audioshare/playback');

/// Si el paquete cae a más de esto de donde debería sonar, se resincroniza.
/// Es más holgado que en la web porque el emisor Android marca el tiempo de
/// captura al recibir cada bloque, con algo de variación.
const _resyncMs = 250;
const _maxSilenceMs = 1000;
const _statsIntervalMs = 2000;

/// Códigos de cierre del WebSocket que no se arreglan reconectando.
const _fatalClose = {
  4400: 'El servidor rechazó el protocolo de audio.',
  4401: 'La llave de emisor ya no es válida para esta sala.',
  4403: 'El emisor te sacó de la sala.',
  4404: 'La sala o el receptor ya no existen.',
  4409: 'Esta sala se abrió desde otro dispositivo o pestaña.',
  4410: 'La sala se cerró.',
  4413: 'La sala alcanzó el máximo de receptores.',
};

LiveAudioEngine createLiveAudioEngine() =>
  Platform.isAndroid ? AndroidLiveAudioEngine() : UnsupportedLiveAudioEngine();

Future<void> preloadLiveAudio() async {}

class AndroidLiveAudioEngine implements LiveAudioEngine {
  final _events = StreamController<LiveEngineEvent>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _pcmSub;
  Timer? _statsTimer;
  Timer? _receiveRetry;
  StreamSubscription<dynamic>? _receiveSub;
  WebSocket? _receiveSocket;
  int _receiveGeneration = 0;
  int _receiveAttempt = 0;
  int? _receiveSampleRate;
  bool _receivePlaying = false;
  int _sequence = 0;
  int _sent = 0;
  double _offsetMs = 0;
  bool _emitting = false;

  @override
  List<CaptureOption> get captureOptions => const [
        CaptureOption(source: CaptureSource.device, available: true),
        CaptureOption(source: CaptureSource.app, available: true),
      ];

  @override
  bool get canReceive => true;

  @override
  Stream<LiveEngineEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> prepareReceiver() async {
    await _playback.invokeMethod<void>('start', {'sampleRate': _sampleRate});
    _receiveSampleRate = _sampleRate;
  }

  /// Android no bloquea el audio por falta de un toque, como los navegadores.
  @override
  Future<bool> unlock() async => true;

  @override
  Future<void> startEmitting({
    required Uri url,
    required String emitterKey,
    required CaptureSource source,
    required double offsetMs,
  }) async {
    if (source == CaptureSource.tab) {
      throw const LiveEngineException('Las pestañas solo existen en el navegador.');
    }
    await stopEmitting();

    // «Una aplicación»: primero se elige la app (si cancela, no se toca la red).
    int? appUid;
    String? appLabel;
    if (source == CaptureSource.app) {
      try {
        final picked = await _control.invokeMapMethod<String, Object?>('pickApp');
        appUid = picked?['uid'] as int?;
        appLabel = picked?['label'] as String?;
      } on PlatformException catch (e) {
        throw LiveEngineException(e.message ?? 'No elegiste ninguna aplicación.');
      }
      if (appUid == null) {
        throw const LiveEngineException('No elegiste ninguna aplicación.');
      }
    }
    final label = appLabel ?? source.title;

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
      await _control.invokeMethod<void>('start', {'uid': appUid});
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
      'source': source.name,
      'label': label,
    }));
    _events.add(LiveStateEvent(
      LiveLinkState.sharing,
      source: source.name,
      label: label,
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
    stopReceiving();
    final generation = ++_receiveGeneration;
    _receiveAttempt = 0;
    _events.add(const LiveStateEvent(LiveLinkState.connecting));
    unawaited(_connectReceiver(url, receiverId, generation));
  }

  @override
  void stopReceiving() {
    ++_receiveGeneration;
    _receiveRetry?.cancel();
    _receiveRetry = null;
    unawaited(_receiveSub?.cancel());
    _receiveSub = null;
    final socket = _receiveSocket;
    _receiveSocket = null;
    if (socket != null) unawaited(socket.close(1000));
    _receiveSampleRate = null;
    _receivePlaying = false;
    unawaited(_playback.invokeMethod<void>('stop').catchError((Object _) {}));
    _events.add(const LiveStateEvent(LiveLinkState.idle));
  }

  Future<void> _connectReceiver(
      Uri url, String receiverId, int generation) async {
    if (generation != _receiveGeneration) return;
    try {
      final socket = await WebSocket.connect(url.toString())
          .timeout(const Duration(seconds: 10));
      if (generation != _receiveGeneration) {
        await socket.close(1000);
        return;
      }
      _receiveSocket = socket;
      _receiveSub = socket.listen(
        (message) =>
            _onReceiveMessage(message, socket, generation, url, receiverId),
        onDone: () => _onReceiveClosed(socket, generation, url, receiverId),
        onError: (Object _) =>
            _onReceiveClosed(socket, generation, url, receiverId),
      );
      socket.add(jsonEncode(
          {'type': 'hello', 'role': 'receiver', 'receiverId': receiverId}));
    } catch (_) {
      if (generation == _receiveGeneration) {
        _scheduleReceiveRetry(url, receiverId, generation);
      }
    }
  }

  void _onReceiveMessage(
    dynamic message,
    WebSocket socket,
    int generation,
    Uri url,
    String receiverId,
  ) {
    if (generation != _receiveGeneration || socket != _receiveSocket) return;
    if (message is String) {
      try {
        final data = jsonDecode(message);
        if (data is! Map) return;
        if (data['type'] == 'ready') {
          _receiveAttempt = 0;
          _events.add(const LiveStateEvent(LiveLinkState.waiting));
        } else if (data['type'] == 'live.state') {
          final active = data['active'] == true;
          _events.add(LiveBroadcastEvent(
            active: active,
            source: data['source'] as String?,
            label: data['label'] as String?,
          ));
          if (!active) {
            _receiveSampleRate = null;
            _receivePlaying = false;
            unawaited(
                _playback.invokeMethod<void>('stop').catchError((Object _) {}));
            _events.add(const LiveStateEvent(LiveLinkState.waiting));
          }
        }
      } catch (_) {
        // Los mensajes de control mal formados se ignoran.
      }
      return;
    }
    if (message is! List<int>) return;
    final packet = message is Uint8List ? message : Uint8List.fromList(message);
    if (!_validPacket(packet)) return;
    final view = ByteData.sublistView(packet);
    final channels = view.getUint8(2);
    final sampleRate = view.getUint32(4, Endian.little);
    final pcm = Uint8List.sublistView(packet, _headerBytes);
    if (_receiveSampleRate != sampleRate) {
      unawaited(
          _playback.invokeMethod<void>('start', {'sampleRate': sampleRate}));
      _receiveSampleRate = sampleRate;
    }
    unawaited(_playback.invokeMethod<void>('write', {'pcm': pcm}));
    if (channels > 0 && !_receivePlaying) {
      _receivePlaying = true;
      _events.add(const LiveStateEvent(LiveLinkState.playing));
    }
  }

  bool _validPacket(Uint8List packet) {
    if (packet.length <= _headerBytes) return false;
    final view = ByteData.sublistView(packet);
    final channels = view.getUint8(2);
    final sampleRate = view.getUint32(4, Endian.little);
    final payloadBytes = packet.length - _headerBytes;
    return view.getUint8(0) == _protocolVersion &&
        view.getUint8(1) == 0 &&
        (channels == 1 || channels == 2) &&
        sampleRate >= 8000 &&
        sampleRate <= 96000 &&
        payloadBytes % (2 * channels) == 0;
  }

  void _onReceiveClosed(
      WebSocket socket, int generation, Uri url, String receiverId) {
    if (generation != _receiveGeneration || socket != _receiveSocket) return;
    _receiveSocket = null;
    _receiveSampleRate = null;
    _receivePlaying = false;
    unawaited(_playback.invokeMethod<void>('stop').catchError((Object _) {}));
    final closeCode = socket.closeCode;
    final fatalMessages = <int, String>{
      4400: 'El servidor rechazó el protocolo de audio.',
      4403: 'El emisor te sacó de la sala.',
      4404: 'La sala o el receptor ya no existen.',
      4409: 'La sala se abrió desde otro dispositivo o pestaña.',
      4410: 'La sala se cerró.',
      4413: 'La sala alcanzó el máximo de receptores.',
    };
    final fatalMessage = fatalMessages[closeCode];
    if (fatalMessage != null) {
      _events.add(LiveStateEvent(LiveLinkState.error,
          message: fatalMessage, code: closeCode));
      return;
    }
    _scheduleReceiveRetry(url, receiverId, generation);
  }

  void _scheduleReceiveRetry(Uri url, String receiverId, int generation) {
    if (generation != _receiveGeneration) return;
    _receiveAttempt++;
    _events.add(const LiveStateEvent(LiveLinkState.reconnecting));
    _receiveRetry?.cancel();
    final delayMs = (_receiveAttempt * 500).clamp(500, 5000);
    _receiveRetry = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_connectReceiver(url, receiverId, generation));
    });
  }

  @override
  void setVolume(double volume) {
    unawaited(_playback.invokeMethod<void>('volume',
        {'volume': volume.clamp(0.0, 1.0)}).catchError((Object _) {}));
  }

  @override
  Future<void> dispose() async {
    stopReceiving();
    await stopEmitting();
    await _events.close();
  }
}
