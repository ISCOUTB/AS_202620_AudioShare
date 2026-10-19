import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../../audio/domain/audio_service.dart';
import '../../../sync/data/sync_event.dart';
import '../../../sync/data/sync_repository.dart';
import '../../../sync/domain/sync_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this.repository,
    AudioService? audio,
    SyncService? sync,
    this.syncRepository,
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

  /// Pista de audio que el receptor descarga al unirse (`GET /track`). Si es
  /// null no se carga audio (comportamiento previo).
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
      if (syncRepository != null) unawaited(_listen(roomId, receiverId));
    });
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
      await audio.start();
      room = await repository.play(room!.id);
      _updateSync();
    });
  }

  Future<void> pause() async {
    if (room == null) return;
    await _run(() async {
      await audio.pause();
      room = await repository.pause(room!.id);
      _updateSync();
    });
  }

  Future<void> setReceiverVolume(String receiverId, double volume) => audio.setVolume(receiverId, volume);

  /// Descarga la pista antes de que llegue el primer `sync.start`.
  Future<void> _loadTrack() async {
    final uri = trackUri;
    if (uri == null) return;
    try {
      await audio.load(uri.toString());
      audioWarning = null;
    } catch (_) {
      audioWarning = 'No se pudo descargar la pista de audio: este receptor no sonará.';
    }
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
    if (current == null || me == null) return;
    final isReceiver = current.participants.any((p) => p.id == me && p.role == ParticipantRole.receiver);
    final startAt = current.startAt;
    if (!isReceiver || !current.playing || startAt == null) return;
    await _scheduleStart(startAt);
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
      final ended = Completer<void>();
      _streamEnded = ended;
      void finish() {
        if (!ended.isCompleted) ended.complete();
      }

      _subscription = repo.events(roomId, receiverId).listen(
        (event) => _eventQueue = _eventQueue.then((_) => _onEvent(event)),
        onError: (Object exception) {
          if (exception is ApiException && exception.statusCode == 404) {
            _streamRejected = true;
          }
          finish();
        },
        onDone: finish,
        cancelOnError: true,
      );
      await ended.future;
      if (_disposed || _streamRejected) break;
      await Future<void>.delayed(reconnectDelay);
    }
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
    unawaited(audio.dispose());
    final ended = _streamEnded;
    if (ended != null && !ended.isCompleted) ended.complete();
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
