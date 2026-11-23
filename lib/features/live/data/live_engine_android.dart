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
  int _sequence = 0;
  int _sent = 0;
  double _offsetMs = 0;
  bool _emitting = false;

  // Estado del receptor.
  WebSocket? _rxSocket;
  Uri? _rxUrl;
  String _rxId = '';
  double _rxOffsetMs = 0;
  int _rxDelayMs = 400;
  int _rxRun = 0; // invalida los callbacks de una conexión anterior
  int _rxAttempt = 0;
  bool _rxActive = false;
  bool _rxStarted = false;
  bool _rxPlaying = false;
  double? _rxNextEndMs; // dónde termina, en reloj del servidor, lo ya encolado
  double _volume = 1;
  int _played = 0;
  int _late = 0;
  int _resyncs = 0;
  int _statsAt = 0;

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
  bool get canReceive => true;

  @override
  Stream<LiveEngineEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> prepareReceiver() async {}

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
    stopReceiving(silent: true);
    final run = ++_rxRun;
    _rxUrl = url.replace(
      scheme: switch (url.scheme) { 'https' => 'wss', 'http' => 'ws', final s => s },
    );
    _rxId = receiverId;
    _rxOffsetMs = offsetMs;
    _rxDelayMs = delayMs > 0 ? delayMs : 400;
    _rxAttempt = 0;
    _rxActive = true;
    _rxStarted = false;
    _rxPlaying = false;
    _rxNextEndMs = null;
    _played = 0;
    _late = 0;
    _resyncs = 0;
    _statsAt = DateTime.now().millisecondsSinceEpoch;
    _events.add(const LiveStateEvent(LiveLinkState.connecting));

    unawaited(() async {
      try {
        await _playback.invokeMethod<void>('start', {'sampleRate': _sampleRate});
        await _playback.invokeMethod<void>('volume', {'volume': _volume});
      } catch (e) {
        if (run != _rxRun) return;
        _rxActive = false;
        _events.add(LiveStateEvent(
          LiveLinkState.error,
          message: 'No se pudo iniciar la reproducción de audio: $e',
        ));
        return;
      }
      if (run == _rxRun) await _connectReceiver(run);
    }());
  }

  Future<void> _connectReceiver(int run) async {
    final url = _rxUrl;
    if (run != _rxRun || url == null) return;

    final WebSocket socket;
    try {
      socket = await WebSocket.connect(url.toString()).timeout(const Duration(seconds: 10));
    } catch (_) {
      _reconnectReceiver(run);
      return;
    }
    if (run != _rxRun) {
      try { await socket.close(1000); } catch (_) {}
      return;
    }
    _rxSocket = socket;

    socket.listen(
      (message) {
        if (run != _rxRun) return;
        if (message is String) {
          _onControl(message);
        } else if (message is List<int>) {
          _onPacket(message is Uint8List ? message : Uint8List.fromList(message));
        }
      },
      onDone: () {
        if (run != _rxRun) return;
        _onReceiverClosed(run, socket.closeCode);
      },
      onError: (Object _) {
        // El cierre posterior informa del motivo.
      },
      cancelOnError: false,
    );
    socket.add(jsonEncode({'type': 'hello', 'role': 'receiver', 'receiverId': _rxId}));
  }

  void _onReceiverClosed(int run, int? code) {
    _rxSocket = null;
    _rxPlaying = false;
    _rxNextEndMs = null;
    final fatal = _fatalClose[code];
    if (fatal != null) {
      _rxActive = false;
      _playback.invokeMethod<void>('stop').catchError((Object _) {});
      _events.add(LiveStateEvent(LiveLinkState.error, message: fatal, code: code));
      return;
    }
    _reconnectReceiver(run);
  }

  void _reconnectReceiver(int run) {
    if (run != _rxRun) return;
    _rxAttempt += 1;
    _events.add(const LiveStateEvent(LiveLinkState.reconnecting));
    Future<void>.delayed(
      Duration(milliseconds: math.min(5000, 500 * _rxAttempt)),
      () => _connectReceiver(run),
    );
  }

  void _onControl(String message) {
    final Object? data;
    try {
      data = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    switch (data['type']) {
      case 'ready':
        _rxAttempt = 0;
        _events.add(const LiveStateEvent(LiveLinkState.waiting));
      case 'live.state':
        final active = data['active'] == true;
        if (!active) {
          _rxNextEndMs = null;
          _rxPlaying = false;
        }
        _events.add(LiveBroadcastEvent(
          active: active,
          source: data['source'] as String?,
          label: data['label'] as String?,
        ));
    }
  }

  /// Decide cuándo debe sonar el paquete (igual que `schedulePacket` de
  /// audioshare_live.js) y se lo pasa al reproductor nativo.
  void _onPacket(Uint8List packet) {
    if (!_rxActive || packet.length <= _headerBytes) return;
    final view = ByteData.sublistView(packet);
    if (view.getUint8(0) != _protocolVersion || view.getUint8(1) != 0) return;
    final channels = view.getUint8(2);
    final rate = view.getUint32(4, Endian.little);
    final payload = packet.length - _headerBytes;
    if ((channels != 1 && channels != 2) || rate != _sampleRate) return;
    if (payload % (2 * channels) != 0) return;

    final frames = payload ~/ (2 * channels);
    final durationMs = frames * 1000 / rate;
    final captureMs = view.getFloat64(12, Endian.little);
    final nowMs = DateTime.now().millisecondsSinceEpoch + _rxOffsetMs;
    final idealMs = captureMs + _rxDelayMs;

    if (idealMs + durationMs < nowMs + 5) {
      _late++; // ya es tarde para tocarlo
      return;
    }

    final next = _rxNextEndMs;
    final resync = next == null || next < nowMs || (idealMs - next).abs() > _resyncMs;
    final double whenMs;
    var silenceMs = 0;
    if (resync) {
      whenMs = math.max(idealMs, nowMs + 10);
      silenceMs = math.min(math.max((whenMs - nowMs).round(), 0), _maxSilenceMs);
      if (_rxStarted) _resyncs++;
    } else {
      whenMs = next;
    }
    _rxNextEndMs = whenMs + durationMs;

    final pcm = channels == 2
        ? Uint8List.fromList(Uint8List.sublistView(packet, _headerBytes))
        : _monoToStereo(packet);

    _playback
        .invokeMethod<void>('write', {
          'pcm': pcm,
          'silenceMs': silenceMs,
          'reset': resync && _rxStarted,
        })
        .catchError((Object _) {});
    _rxStarted = true;
    _played++;

    if (!_rxPlaying) {
      _rxPlaying = true;
      _events.add(const LiveStateEvent(LiveLinkState.playing));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _statsAt >= _statsIntervalMs) {
      _statsAt = now;
      _events.add(LiveStatsEvent(
        latencyMs: (whenMs - nowMs).round(),
        played: _played,
        late: _late,
        resyncs: _resyncs,
      ));
    }
  }

  Uint8List _monoToStereo(Uint8List packet) {
    final samples = (packet.length - _headerBytes) ~/ 2;
    final out = Uint8List(samples * 4);
    for (var i = 0; i < samples; i++) {
      final lo = packet[_headerBytes + i * 2];
      final hi = packet[_headerBytes + i * 2 + 1];
      out[i * 4] = lo;
      out[i * 4 + 1] = hi;
      out[i * 4 + 2] = lo;
      out[i * 4 + 3] = hi;
    }
    return out;
  }

  @override
  void stopReceiving({bool silent = false}) {
    final wasActive = _rxActive || _rxSocket != null;
    _rxRun++; // los callbacks pendientes quedan sin efecto
    _rxActive = false;
    _rxPlaying = false;
    _rxNextEndMs = null;
    final socket = _rxSocket;
    _rxSocket = null;
    try { socket?.close(1000); } catch (_) {}
    if (wasActive) {
      _playback.invokeMethod<void>('stop').catchError((Object _) {});
      if (!silent && !_events.isClosed) _events.add(const LiveStateEvent(LiveLinkState.idle));
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    if (_rxActive) {
      _playback.invokeMethod<void>('volume', {'volume': _volume}).catchError((Object _) {});
    }
  }

  @override
  Future<void> dispose() async {
    stopReceiving(silent: true);
    await _teardown();
    await _events.close();
  }
}
