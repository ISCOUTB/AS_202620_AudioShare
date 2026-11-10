import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_control_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../../audio/data/audio_track_repository.dart';
import '../../../audio/domain/audio_service.dart';
import '../../../sync/data/sync_event.dart';
import '../../../sync/data/sync_repository.dart';
import '../../../sync/domain/sync_service.dart';

/// Estado de la pista en ESTE dispositivo (solo receptores).
enum TrackStatus { none, downloading, ready, failed }

/// Por qué terminó la estancia de este dispositivo en la sala.
enum RoomEnd {
  /// Salió por su cuenta.
  left,

  /// El emisor lo expulsó.
  removed,

  /// La sala se cerró (el emisor la cerró, o este dispositivo si es el emisor).
  closed,

  /// La sala ya no existe (caducó o se borró).
  gone,
}

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this.repository,
    AudioService? audio,
    SyncService? sync,
    this.syncRepository,
    this.control,
    this.trackRepository,
    this.trackUri,
    int Function()? clock,
    Future<void> Function(Duration)? wait,
    this.reconnectDelay = const Duration(seconds: 2),
  })  : audio = audio ?? MockAudioService(),
        sync = sync ?? SyncService(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _wait = wait ?? ((duration) => Future<void>.delayed(duration));

  final RoomRepository repository;
  final AudioService audio;
  final SyncService sync;

  /// Si es null, el receptor no calibra su reloj ni envía ACK (comportamiento previo).
  final SyncRepository? syncRepository;

  /// Salir, expulsar, cerrar la sala y eventos del emisor. Si es null esas
  /// acciones no están disponibles (comportamiento previo).
  final RoomControlRepository? control;

  /// Para que el emisor cambie la canción de la sala.
  final AudioTrackRepository? trackRepository;

  /// URL base del backend; el receptor descarga su pista con
  /// `GET /rooms/:roomId/track`. Si es null no se carga audio.
  final Uri? trackUri;
  final int Function() _clock;
  final Future<void> Function(Duration) _wait;

  /// Espera antes de reabrir el stream si se corta.
  final Duration reconnectDelay;

  Room? room;
  String? error;
  bool loading = false;
  String? identity;
  SyncSnapshot synchronization = const SyncSnapshot();

  /// Offset de reloj (reloj_servidor − reloj_local) estimado con `GET /time`;
  /// null si no se ha calibrado o la calibración falló.
  double? clockOffsetMs;

  /// Aviso no fatal cuando la calibración falla: el receptor sigue en la sala.
  String? calibrationWarning;

  /// Aviso no fatal si la pista no se pudo descargar.
  String? audioWarning;

  /// Si no es null, este dispositivo ya no está en la sala y la pantalla debe
  /// cerrarse.
  RoomEnd? ended;

  /// Este dispositivo es el emisor de la sala.
  bool get isEmitter {
    final current = room;
    return current != null &&
        current.participants.any((p) => p.role == ParticipantRole.emitter && p.id == identity);
  }

  /// Estado de descarga de la pista en este dispositivo. Un receptor solo abre
  /// el stream de eventos (y por tanto cuenta como conectado) cuando está `ready`.
  TrackStatus trackStatus = TrackStatus.none;

  static const double defaultVolume = 0.8;
  final Map<String, double> _volumes = {};

  /// Volumen mostrado para [participantId] (el volumen es local de cada teléfono).
  double volumeOf(String participantId) => _volumes[participantId] ?? defaultVolume;

  bool _listening = false;
  bool _watching = false;
  bool _watchRejected = false;
  int _loadedTrackVersion = -1;
  StreamSubscription<SyncEvent>? _watchSubscription;
  Completer<void>? _watchEnded;

  /// Sin `trackUri` no hay audio que cargar; con él, hace falta la pista lista.
  bool get _trackUsable => trackUri == null || trackStatus == TrackStatus.ready;

  int? _ackedStartAt;
  bool _disposed = false;
  bool _streamRejected = false;
  StreamSubscription<SyncEvent>? _subscription;
  Completer<void>? _streamEnded;
  Future<void> _eventQueue = Future<void>.value();

  Future<void> createRoom(String emitterId) async {
    await _run(() async {
      identity = emitterId;
      final id = await repository.createRoom(emitterId);
      room = await repository.getRoom(id);
      _updateSync();
      await _calibrateClock();
      _startWatching();
    });
  }

  /// Vuelve a una sala de la que este dispositivo es emisor (la llave ya está
  /// registrada en el cliente de red).
  Future<void> restoreEmitter(String roomId, String emitterId) async {
    await _run(() async {
      identity = emitterId;
      room = await repository.getRoom(roomId);
      _updateSync();
      await _calibrateClock();
      if (room!.trackVersion > 0) await _loadTrack();
      _startWatching();
    });
  }

  /// El emisor descarga su propia pista para oírla igual que los receptores.
  Future<void> prepareOwnTrack() async {
    final current = room;
    if (current == null) return;
    await _run(() async {
      room = await repository.getRoom(current.id);
      _updateSync();
      await _loadTrack();
    });
  }

  /// El emisor reemplaza la canción de la sala: la sala queda detenida y los
  /// receptores descargan la nueva al recibir `track.changed`.
  Future<void> changeTrack(Uint8List bytes, String trackName) async {
    final current = room;
    final uploader = trackRepository;
    if (current == null || uploader == null || !isEmitter) return;
    await _run(() async {
      await audio.pause();
      await uploader.upload(current.id, bytes, trackName: trackName);
      room = await repository.getRoom(current.id);
      _updateSync();
      _ackedStartAt = null;
      await _loadTrack();
    });
  }

  /// Sale de la sala. Un receptor se quita de la lista; el emisor solo se va y
  /// la sala sigue activa (puede volver con su llave).
  Future<void> leaveRoom() async {
    final current = room;
    final me = identity;
    final repo = control;
    if (current != null && me != null && repo != null && !isEmitter) {
      try {
        await repo.leave(current.id, me);
      } catch (_) {
        // Salir no debe fallar por la red: el servidor lo dará por desconectado.
      }
    }
    _end(RoomEnd.left);
  }

  /// El emisor cierra la sala para todos.
  Future<void> closeRoom() async {
    final current = room;
    final repo = control;
    if (current == null || repo == null || !isEmitter) return;
    await _run(() => repo.closeRoom(current.id));
    if (error == null) _end(RoomEnd.closed);
  }

  /// El emisor expulsa a un receptor.
  Future<void> kick(String participantId) async {
    final current = room;
    final repo = control;
    if (current == null || repo == null || !isEmitter) return;
    await _run(() async {
      await repo.kick(current.id, participantId);
      room = await repository.getRoom(current.id);
      _updateSync();
    });
  }

  Future<void> joinRoom(String roomId, String receiverId) async {
    await _run(() async {
      identity = receiverId;
      await repository.joinRoom(roomId, receiverId);
      room = await repository.getRoom(roomId);
      _updateSync();
      await _calibrateClock();
      await _loadTrack();
      await _startIfScheduled();
      _startListening();
    });
  }

  /// Reintenta la descarga de la pista tras un fallo. Si queda lista, el
  /// receptor abre el stream y, si la sala ya está sonando, se sincroniza.
  Future<void> retryTrack() async {
    if (room == null || trackStatus == TrackStatus.downloading) return;
    await _run(() async {
      await _loadTrack();
      if (trackStatus != TrackStatus.ready) return;
      room = await repository.getRoom(room!.id);
      _updateSync();
      await _startIfScheduled();
      _startListening();
    });
  }

  void _startListening() {
    final current = room;
    final me = identity;
    if (syncRepository == null || current == null || me == null) return;
    // El emisor no es un receptor: no tiene stream propio (usa `watch`).
    if (isEmitter) return;
    if (_listening || !_trackUsable) return;
    _listening = true;
    unawaited(_listen(current.id, me));
  }

  Future<void> refresh() async {
    if (room == null) return;
    await _run(() async {
      room = await repository.getRoom(room!.id);
      _updateSync();
      await _startIfScheduled();
    });
  }

  Future<void> play() async {
    if (room == null) return;
    await _run(() async {
      room = await repository.play(room!.id);
      _updateSync();
      await _startOwnAudio(room!);
    });
  }

  Future<void> pause() async {
    if (room == null) return;
    await _run(() async {
      await audio.pause();
      room = await repository.pause(room!.id);
      _updateSync();
      await audio.seek(room!.positionMs);
    });
  }

  /// El emisor oye la pista arrancando en el mismo `startAt` que los
  /// receptores. Sin reloj calibrado o sin pista lista, arranca de inmediato
  /// (comportamiento previo). No envía ACK: no cuenta como receptor.
  Future<void> _startOwnAudio(Room current) async {
    final startAt = current.startAt;
    final offset = clockOffsetMs;
    if (startAt == null || offset == null || !_trackUsable) {
      await audio.start();
      return;
    }
    await audio.seek(current.positionMs);
    final delay = sync.delayUntilStartMs(startAt: startAt, localNow: _clock(), offsetMs: offset);
    if (delay > 0) await _wait(Duration(milliseconds: delay));
    await audio.start();
  }

  Future<void> setReceiverVolume(String receiverId, double volume) async {
    final value = volume.clamp(0.0, 1.0).toDouble();
    _volumes[receiverId] = value;
    notifyListeners();
    await audio.setVolume(receiverId, value);
  }

  /// Descarga la pista antes de que llegue el primer `sync.start`.
  Future<void> _loadTrack() async {
    final uri = trackUri;
    final current = room;
    if (uri == null || current == null) return;
    trackStatus = TrackStatus.downloading;
    audioWarning = null;
    _loadedTrackVersion = current.trackVersion;
    notifyListeners();
    try {
      final roomTrackUri = uri.resolve('/rooms/${Uri.encodeComponent(current.id)}/track');
      await audio.load(roomTrackUri.toString());
      trackStatus = TrackStatus.ready;
      audioWarning = null;
    } catch (_) {
      trackStatus = TrackStatus.failed;
      audioWarning = 'No se pudo descargar la pista de audio: este receptor no sonará hasta que reintentes.';
    }
    notifyListeners();
  }

  Future<void> _calibrateClock() async {
    final repo = syncRepository;
    if (repo == null) return;
    try {
      clockOffsetMs = await sync.calibrate(fetchServerTime: repo.serverTime, now: _clock);
      calibrationWarning = null;
    } catch (_) {
      clockOffsetMs = null;
      calibrationWarning = 'No se pudo calibrar el reloj: el arranque no estará sincronizado.';
    }
  }

  /// Respaldo al stream: si al actualizar la sala hay un `startAt` que aún no
  /// se atendió, lo atiende igual (por ejemplo, si el stream estaba caído).
  Future<void> _startIfScheduled() async {
    final current = room;
    final me = identity;
    if (current == null || me == null || !_trackUsable) return;
    final isReceiver = current.participants.any((p) => p.id == me && p.role == ParticipantRole.receiver);
    final startAt = current.startAt;
    if (!isReceiver || !current.playing || startAt == null) return;
    final serverNow = _clock() + (clockOffsetMs ?? 0);
    final elapsedMs = serverNow - startAt;
    await _scheduleStart(
      startAt,
      positionMs: current.positionMs + (elapsedMs > 0 ? elapsedMs.toInt() : 0),
    );
  }

  /// Espera hasta [startAt] (reloj del servidor), arranca el audio y envía el
  /// ACK (ADR-0007). Cada `startAt` se atiende una sola vez, venga del stream
  /// o de una actualización de la sala.
  Future<void> _scheduleStart(int startAt, {int? positionMs}) async {
    final current = room;
    final repo = syncRepository;
    final offset = clockOffsetMs;
    final me = identity;
    if (current == null || repo == null || offset == null || me == null) return;
    // Sin la pista lista no se arranca ni se envía ACK: sería un ACK falso.
    if (!_trackUsable) return;
    if (startAt == _ackedStartAt) return;

    _ackedStartAt = startAt;
    try {
      // Colocar la pista antes de calcular la espera: el seek tarda unos ms.
      await audio.seek(positionMs ?? current.positionMs);
      final delay = sync.delayUntilStartMs(startAt: startAt, localNow: _clock(), offsetMs: offset);
      if (delay > 0) await _wait(Duration(milliseconds: delay));
      final startedAt = _clock();
      await audio.start();
      await repo.ackStart(roomId: current.id, receiverId: me, startedAt: startedAt, offsetMs: offset);
    } catch (_) {
      _ackedStartAt = null;
      rethrow;
    }
  }

  /// Mantiene abierto el stream NDJSON del receptor y lo reabre si se corta.
  /// Se detiene al liberar el view model o si el servidor responde 404.
  Future<void> _listen(String roomId, String receiverId) async {
    final repo = syncRepository!;
    while (!_disposed && !_streamRejected) {
      final streamEnded = Completer<void>();
      _streamEnded = streamEnded;
      void finish() {
        if (!streamEnded.isCompleted) streamEnded.complete();
      }

      _subscription = repo.events(roomId, receiverId).listen(
        (event) => _eventQueue = _eventQueue.then((_) => _onEvent(event)),
        onError: (Object exception) {
          if (exception is ApiException && exception.statusCode == 404) {
            _streamRejected = true;
            _end(RoomEnd.gone);
          }
          finish();
        },
        onDone: finish,
        cancelOnError: true,
      );
      await streamEnded.future;
      if (_disposed || _streamRejected) break;
      await Future<void>.delayed(reconnectDelay);
    }
    _listening = false;
  }

  void _startWatching() {
    final current = room;
    final repo = control;
    if (repo == null || current == null || _watching || !isEmitter) return;
    _watching = true;
    unawaited(_watch(current.id, repo));
  }

  /// Eventos de la sala para el emisor; se reabre si se corta. Se detiene al
  /// liberar el view model o si el servidor rechaza la llave o la sala no existe.
  Future<void> _watch(String roomId, RoomControlRepository repo) async {
    var first = true;
    while (!_disposed && !_watchRejected && ended == null) {
      if (!first) {
        // Pudo haber cambios mientras no había conexión.
        _eventQueue = _eventQueue.then((_) => _resync());
      }
      first = false;
      final watchEnded = Completer<void>();
      _watchEnded = watchEnded;
      void finish() {
        if (!watchEnded.isCompleted) watchEnded.complete();
      }

      _watchSubscription = repo.watch(roomId).listen(
        (event) => _eventQueue = _eventQueue.then((_) => _onEvent(event)),
        onError: (Object exception) {
          if (exception is ApiException) {
            final status = exception.statusCode;
            if (status == 401 || status == 403 || status == 404) _watchRejected = true;
            if (status == 404) _end(RoomEnd.gone);
          }
          finish();
        },
        onDone: finish,
        cancelOnError: true,
      );
      await watchEnded.future;
      if (_disposed || _watchRejected) break;
      await Future<void>.delayed(reconnectDelay);
    }
    _watching = false;
  }

  Future<void> _resync() async {
    try {
      await _reloadRoom();
    } catch (_) {
      // Se reintentará en la siguiente conexión o al refrescar.
    }
  }

  void _end(RoomEnd reason) {
    if (ended != null || _disposed) return;
    ended = reason;
    _streamRejected = true;
    _watchRejected = true;
    unawaited(_subscription?.cancel());
    unawaited(_watchSubscription?.cancel());
    final listening = _streamEnded;
    if (listening != null && !listening.isCompleted) listening.complete();
    final watching = _watchEnded;
    if (watching != null && !watching.isCompleted) watching.complete();
    unawaited(audio.pause());
    notifyListeners();
  }

  Future<void> _onEvent(SyncEvent event) async {
    if (_disposed) return;
    try {
      if (event is SyncStartEvent) {
        await _scheduleStart(event.startAt, positionMs: event.positionMs);
        await _reloadRoom();
      } else if (event is SyncPauseEvent) {
        await audio.pause();
        await audio.seek(event.positionMs);
        await _reloadRoom();
      } else if (event is ParticipantEvent) {
        if (event.change == ParticipantChange.left &&
            event.removed &&
            event.participantId == identity) {
          _end(RoomEnd.removed);
          return;
        }
        await _reloadRoom();
      } else if (event is TrackChangedEvent) {
        // La sala queda detenida en 0 con la pista nueva.
        _ackedStartAt = null;
        await audio.pause();
        await _reloadRoom();
        if ((room?.trackVersion ?? 0) != _loadedTrackVersion) await _loadTrack();
      } else if (event is RoomClosedEvent) {
        _end(RoomEnd.closed);
      }
    } on ApiException catch (exception) {
      if (exception.statusCode == 404) {
        _end(RoomEnd.gone);
      } else {
        error = exception.toString();
        notifyListeners();
      }
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
    }
  }

  Future<void> _reloadRoom() async {
    final current = room;
    if (current == null) return;
    room = await repository.getRoom(current.id);
    _updateSync();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _watchSubscription?.cancel();
    unawaited(audio.dispose());
    final listening = _streamEnded;
    if (listening != null && !listening.isCompleted) listening.complete();
    final watching = _watchEnded;
    if (watching != null && !watching.isCompleted) watching.complete();
    super.dispose();
  }

  void _updateSync() {
    final current = room!;
    synchronization = sync.fromRoom(
      startAt: current.startAt,
      playing: current.playing,
      positionMs: current.positionMs,
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
