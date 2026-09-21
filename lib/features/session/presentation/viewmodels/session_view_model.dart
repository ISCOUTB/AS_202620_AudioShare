import 'package:flutter/foundation.dart';

import '../../data/models/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../../audio/domain/audio_service.dart';
import '../../../sync/domain/sync_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required this.repository, AudioService? audio, SyncService? sync})
      : audio = audio ?? MockAudioService(),
        sync = sync ?? SyncService();

  final RoomRepository repository;
  final AudioService audio;
  final SyncService sync;

  Room? room;
  String? error;
  bool loading = false;
  String? identity;
  SyncSnapshot synchronization = const SyncSnapshot();

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
    });
  }

  Future<void> refresh() async {
    if (room == null) return;
    await _run(() async {
      room = await repository.getRoom(room!.id);
      _updateSync();
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
