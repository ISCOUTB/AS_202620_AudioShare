import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../domain/live_audio_engine.dart';

/// Archivo del motor, copiado desde `web/` a la raíz del sitio al compilar.
const _scriptPath = 'audioshare_live.js';

Future<void>? _loading;

@JS('AudioShareLive')
external _AudioShareLive? get _audioShareLive;

/// API de `web/audioshare_live.js`. Todo viaja como texto (JSON): el audio no
/// pasa por Dart y las promesas nunca se rechazan (devuelven el error como texto).
extension type _AudioShareLive._(JSObject _) implements JSObject {
  external JSString capabilities();
  external JSPromise<JSString> prepareReceiver();
  external JSPromise<JSString> unlock();
  external JSPromise<JSString> startEmit(JSString config, JSFunction listener);
  external void stopEmit();
  external void startReceive(JSString config, JSFunction listener);
  external void stopReceive();
  external void setVolume(JSNumber volume);
}

LiveAudioEngine createLiveAudioEngine() => WebLiveAudioEngine();

/// Carga el motor al arrancar la app, para que desbloquear el audio no tenga
/// que esperar a la red dentro del gesto del usuario.
Future<void> preloadLiveAudio() async {
  final pending = _loading ??= _loadScript();
  try {
    await pending;
  } catch (_) {
    _loading = null; // permite reintentar
    rethrow;
  }
}

Future<void> _loadScript() async {
  if (_audioShareLive != null) return;
  final done = Completer<void>();
  final script = (web.document.createElement('script') as web.HTMLScriptElement)
    ..src = _scriptPath
    ..async = true;
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) => done.completeError(
        const LiveEngineException(
          'No se pudo cargar el motor de audio ($_scriptPath). '
          'Recarga la página o vuelve a compilar la app.',
        ),
      )).toJS;
  web.document.head!.append(script);
  await done.future;
  if (_audioShareLive == null) {
    throw const LiveEngineException('El motor de audio se cargó, pero no se inició.');
  }
}

class WebLiveAudioEngine implements LiveAudioEngine {
  WebLiveAudioEngine();

  final _events = StreamController<LiveEngineEvent>.broadcast();
  late final JSFunction _listener = _onEvent.toJS;
  List<CaptureOption>? _options;
  bool _canReceive = false;
  bool _disposed = false;

  void _onEvent(JSString json) {
    if (_disposed) return;
    final event = LiveEngineEvent.parse(json.toDart);
    if (event != null) _events.add(event);
  }

  @override
  List<CaptureOption> get captureOptions => _options ?? const [];

  @override
  bool get canReceive => _canReceive;

  @override
  Stream<LiveEngineEvent> get events => _events.stream;

  _AudioShareLive _api() {
    final api = _audioShareLive;
    if (api == null) {
      throw const LiveEngineException('El motor de audio no está cargado.');
    }
    return api;
  }

  @override
  Future<void> initialize() async {
    if (_options != null) return;
    try {
      await preloadLiveAudio();
      final caps = jsonDecode(_api().capabilities().toDart) as Map<String, dynamic>;
      _canReceive = caps['receive'] == true;
      _options = [
        for (final source in CaptureSource.values) _optionFrom(source, caps[source.name]),
      ];
    } on LiveEngineException catch (exception) {
      _options = [
        for (final source in CaptureSource.values)
          CaptureOption(source: source, available: false, reason: exception.message),
      ];
    }
  }

  static CaptureOption _optionFrom(CaptureSource source, Object? raw) {
    final map = raw is Map ? raw : const {};
    final available = map['ok'] == true;
    return CaptureOption(
      source: source,
      available: available,
      reason: available ? null : (map['reason'] as String?) ?? 'No disponible en este navegador.',
    );
  }

  @override
  Future<void> prepareReceiver() async {
    // Si el motor ya está cargado, la llamada a JavaScript ocurre de inmediato,
    // dentro del gesto del usuario: así el navegador permite el audio.
    var api = _audioShareLive;
    if (api == null) {
      await initialize();
      api = _audioShareLive;
    }
    if (api == null) return;
    await api.prepareReceiver().toDart;
  }

  @override
  Future<bool> unlock() async {
    final result = await _api().unlock().toDart;
    return result.toDart == 'running';
  }

  @override
  Future<void> startEmitting({
    required Uri url,
    required String emitterKey,
    required CaptureSource source,
    required double offsetMs,
  }) async {
    await initialize();
    final config = jsonEncode({
      'url': url.toString(),
      'key': emitterKey,
      'source': source.name,
      'offsetMs': offsetMs,
    });
    final result = await _api().startEmit(config.toJS, _listener).toDart;
    final error = result.toDart;
    if (error.isNotEmpty) throw LiveEngineException(error);
  }

  @override
  Future<void> stopEmitting() async => _audioShareLive?.stopEmit();

  @override
  void startReceiving({
    required Uri url,
    required String receiverId,
    required double offsetMs,
    int delayMs = 400,
  }) {
    final api = _audioShareLive;
    if (api == null) {
      _events.add(const LiveStateEvent(
        LiveLinkState.error,
        message: 'El motor de audio no está cargado.',
      ));
      return;
    }
    final config = jsonEncode({
      'url': url.toString(),
      'receiverId': receiverId,
      'offsetMs': offsetMs,
      'delayMs': delayMs,
    });
    api.startReceive(config.toJS, _listener);
  }

  @override
  void stopReceiving() => _audioShareLive?.stopReceive();

  @override
  void setVolume(double volume) => _audioShareLive?.setVolume(volume.toJS);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _audioShareLive?.stopEmit();
    _audioShareLive?.stopReceive();
    await _events.close();
  }
}
