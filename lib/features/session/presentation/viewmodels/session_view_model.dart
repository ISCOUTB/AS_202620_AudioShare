import 'package:flutter/foundation.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../../audio/domain/audio_service.dart';
import '../../../sync/data/sync_repository.dart';
import '../../../sync/domain/sync_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this.repository,
    AudioService? audio,
    SyncService? sync,
    this.syncRepository,
    int Function()? clock,
    Future<void> Function(Duration)? wait,
  })  : audio = audio ?? MockAudioService(),
        sync = sync ?? SyncService(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _wait = wait ?? ((duration) => Future<void>.delayed(duration));

  final RoomRepository repository;
  final AudioService audio;
  final SyncService sync;

  /// Si es null, el receptor no calibra su reloj ni envía ACK (comportamiento previo).
  final SyncRepository? syncRepository;
  final int Function() _clock;
  final Future<void> Function(Duration) _wait;

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

  int? _ackedStartAt;

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

  /// Si este dispositivo es receptor y la sala tiene un `startAt` que aún no
  /// atendió, espera hasta ese instante (en el reloj del servidor), arranca el
  /// audio y envía el ACK (ADR-0007). Cada `startAt` se atiende una sola vez.
  Future<void> _startIfScheduled() async {
    final current = room;
    final repo = syncRepository;
    final offset = clockOffsetMs;
    final me = identity;
    if (current == null || repo == null || offset == null || me == null) return;
    final isReceiver = current.participants.any((p) => p.id == me && p.role == ParticipantRole.receiver);
    final startAt = current.startAt;
    if (!isReceiver || !current.playing || startAt == null || startAt == _ackedStartAt) return;

    _ackedStartAt = startAt;
    try {
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
