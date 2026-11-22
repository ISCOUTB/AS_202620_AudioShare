import 'dart:async';
import 'dart:convert';

/// Qué parte del audio comparte el emisor (ADR-0015).
enum CaptureSource {
  /// Todo lo que suena en el dispositivo.
  device,

  /// El audio de una sola aplicación.
  app,

  /// El audio de una pestaña del navegador.
  tab;

  String get title => switch (this) {
        CaptureSource.device => 'Todo el dispositivo',
        CaptureSource.app => 'Una aplicación',
        CaptureSource.tab => 'Una pestaña',
      };

  String get description => switch (this) {
        CaptureSource.device => 'Todo lo que suena en el equipo, de cualquier programa.',
        CaptureSource.app => 'Solo el audio de la aplicación que elijas.',
        CaptureSource.tab => 'Solo el audio de una pestaña del navegador.',
      };

  /// Qué hacer en el selector del navegador para que el audio sí se comparta.
  String get browserHint => switch (this) {
        CaptureSource.device =>
          'El navegador abrirá su selector: elige «Pantalla completa» y activa «Compartir audio del sistema».',
        CaptureSource.app => 'Elige la aplicación cuando el sistema te lo pida.',
        CaptureSource.tab =>
          'El navegador abrirá su selector: elige la pestaña y activa «Compartir audio de la pestaña».',
      };

  /// Interpreta el nombre que viaja en el protocolo (`device`, `app`, `tab`).
  static CaptureSource? fromWire(Object? value) {
    for (final source in values) {
      if (source.name == value) return source;
    }
    return null;
  }
}

/// Si este dispositivo puede compartir [source] y, si no, por qué.
class CaptureOption {
  const CaptureOption({required this.source, required this.available, this.reason});

  final CaptureSource source;
  final bool available;

  /// Explicación para el usuario cuando [available] es false.
  final String? reason;
}

/// Estado de la conexión de audio en vivo de este dispositivo.
enum LiveLinkState {
  /// Sin conexión de audio.
  idle,

  /// Abriendo la conexión (o esperando el permiso del navegador).
  connecting,

  /// Receptor conectado; el emisor aún no comparte audio.
  waiting,

  /// Emisor: el audio se está enviando.
  sharing,

  /// Receptor: el audio está sonando.
  playing,

  /// Se perdió la conexión y se está reintentando.
  reconnecting,

  /// El navegador bloqueó el audio hasta que el usuario toque la pantalla.
  blocked,

  /// Fallo que no se resuelve solo; ver el mensaje.
  error,
}

/// Evento que el motor de audio comunica al resto de la app.
sealed class LiveEngineEvent {
  const LiveEngineEvent();

  /// Interpreta un evento JSON del motor. Devuelve null si no es válido.
  static LiveEngineEvent? parse(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! Map) return null;
      switch (data['type']) {
        case 'state':
          final state = _stateFrom(data['state']);
          if (state == null) return null;
          return LiveStateEvent(
            state,
            message: data['message'] as String?,
            source: data['source'] as String?,
            label: data['label'] as String?,
            code: (data['code'] as num?)?.toInt(),
          );
        case 'live':
          return LiveBroadcastEvent(
            active: data['active'] == true,
            source: data['source'] as String?,
            label: data['label'] as String?,
          );
        case 'stats':
          return LiveStatsEvent(
            latencyMs: (data['latencyMs'] as num?)?.toInt(),
            played: (data['played'] as num?)?.toInt(),
            late: (data['late'] as num?)?.toInt(),
            resyncs: (data['resyncs'] as num?)?.toInt(),
            sent: (data['sent'] as num?)?.toInt(),
            dropped: (data['dropped'] as num?)?.toInt(),
          );
      }
    } catch (_) {
      // Un evento mal formado se ignora.
    }
    return null;
  }

  static LiveLinkState? _stateFrom(Object? raw) => switch (raw) {
        'connecting' => LiveLinkState.connecting,
        'connected' => LiveLinkState.waiting,
        'sharing' => LiveLinkState.sharing,
        'playing' => LiveLinkState.playing,
        'reconnecting' => LiveLinkState.reconnecting,
        'blocked' => LiveLinkState.blocked,
        'error' => LiveLinkState.error,
        'closed' || 'ended' => LiveLinkState.idle,
        _ => null,
      };
}

/// Cambio del estado de la conexión de audio de este dispositivo.
final class LiveStateEvent extends LiveEngineEvent {
  const LiveStateEvent(this.state, {this.message, this.source, this.label, this.code});

  final LiveLinkState state;
  final String? message;
  final String? source;
  final String? label;

  /// Código de cierre del WebSocket cuando el estado es un error.
  final int? code;
}

/// Receptor: el emisor empezó o dejó de compartir audio.
final class LiveBroadcastEvent extends LiveEngineEvent {
  const LiveBroadcastEvent({required this.active, this.source, this.label});

  final bool active;
  final String? source;
  final String? label;
}

/// Medidas periódicas: retardo y descartes (receptor), enviados (emisor).
final class LiveStatsEvent extends LiveEngineEvent {
  const LiveStatsEvent({
    this.latencyMs,
    this.played,
    this.late,
    this.resyncs,
    this.sent,
    this.dropped,
  });

  final int? latencyMs;
  final int? played;
  final int? late;
  final int? resyncs;
  final int? sent;
  final int? dropped;
}

/// El motor no pudo empezar; [message] se muestra tal cual al usuario.
class LiveEngineException implements Exception {
  const LiveEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Captura el audio del emisor y reproduce el de los receptores en tiempo real.
///
/// En Flutter Web lo implementa `audioshare_live.js` (Web Audio y
/// `getDisplayMedia`). El audio no pasa por Dart: aquí solo se arranca y se
/// detiene, y se reciben eventos de estado.
abstract interface class LiveAudioEngine {
  /// Qué puede compartir este dispositivo. Vacío hasta llamar a [initialize].
  List<CaptureOption> get captureOptions;

  /// Si este dispositivo puede reproducir una transmisión en vivo.
  bool get canReceive;

  Stream<LiveEngineEvent> get events;

  /// Carga el motor y averigua las capacidades. Se puede llamar varias veces.
  Future<void> initialize();

  /// Desbloquea el audio. Hay que llamarlo desde un gesto del usuario (un
  /// toque), porque los navegadores no dejan sonar nada antes.
  Future<void> prepareReceiver();

  /// Reintenta desbloquear el audio; devuelve si ya puede sonar.
  Future<bool> unlock();

  /// Pide al usuario qué compartir y empieza a enviar audio. Debe llamarse
  /// desde un gesto del usuario. Lanza [LiveEngineException] si no se pudo.
  Future<void> startEmitting({
    required Uri url,
    required String emitterKey,
    required CaptureSource source,
    required double offsetMs,
  });

  Future<void> stopEmitting();

  /// Se conecta a la sala y reproduce lo que el emisor comparta. [offsetMs] es
  /// el desfase de reloj (servidor − local) calibrado con `GET /time`.
  void startReceiving({
    required Uri url,
    required String receiverId,
    required double offsetMs,
    int delayMs = 400,
  });

  void stopReceiving();

  /// Volumen de reproducción de este dispositivo (0.0 a 1.0).
  void setVolume(double volume);

  Future<void> dispose();
}

/// Motor de las plataformas que aún no soportan audio en vivo: no comparte ni
/// reproduce nada y explica por qué.
class UnsupportedLiveAudioEngine implements LiveAudioEngine {
  static const reason =
      'Este dispositivo todavía no puede transmitir audio en vivo. '
      'Abre AudioShare en Chrome o Edge desde un computador.';

  final _events = StreamController<LiveEngineEvent>.broadcast();

  @override
  List<CaptureOption> get captureOptions => [
        for (final source in CaptureSource.values)
          CaptureOption(source: source, available: false, reason: reason),
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
    throw const LiveEngineException(reason);
  }

  @override
  Future<void> stopEmitting() async {}

  @override
  void startReceiving({
    required Uri url,
    required String receiverId,
    required double offsetMs,
    int delayMs = 400,
  }) {
    _events.add(const LiveStateEvent(LiveLinkState.error, message: reason));
  }

  @override
  void stopReceiving() {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> dispose() => _events.close();
}
