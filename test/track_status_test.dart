import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/audio/domain/audio_service.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/viewmodels/session_view_model.dart';
import 'package:audioshare/features/sync/data/sync_event.dart';
import 'package:audioshare/features/sync/data/sync_repository.dart';

class _Rooms implements RoomRepository {
  _Rooms({this.playing = false, this.startAt});

  final bool playing;
  final int? startAt;

  @override
  Future<String> createRoom(String emitterId) async => 'room-1';
  @override
  Future<String> joinRoom(String roomId, String receiverId) async => receiverId;
  @override
  Future<Room> getRoom(String roomId) async => Room(
        id: roomId,
        createdAt: DateTime(2026),
        status: playing ? PlaybackStatus.playing : PlaybackStatus.stopped,
        playing: playing,
        positionMs: 0,
        startAt: startAt,
        participants: [
          Participant(id: 'rx', role: ParticipantRole.receiver, joinedAt: DateTime(2026)),
        ],
      );
  @override
  Future<Room> play(String roomId) => getRoom(roomId);
  @override
  Future<Room> pause(String roomId) => getRoom(roomId);
}

class _Sync implements SyncRepository {
  int opened = 0;
  final acks = <int>[];
  final controller = StreamController<SyncEvent>.broadcast();

  @override
  Stream<SyncEvent> events(String roomId, String receiverId) {
    opened++;
    return controller.stream;
  }

  @override
  Future<int> serverTime() async => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<void> ackStart({
    required String roomId,
    required String receiverId,
    required int startedAt,
    required double offsetMs,
  }) async {
    acks.add(startedAt);
  }
}

class _FlakyAudio extends MockAudioService {
  _FlakyAudio({this.failures = 1});

  int failures;
  int loads = 0;
  int starts = 0;

  @override
  Future<void> load(String url) async {
    loads++;
    if (failures > 0) {
      failures--;
      throw Exception('sin red');
    }
  }

  @override
  Future<void> start() async => starts++;
}

SessionViewModel _viewModel(_Rooms rooms, _Sync sync, _FlakyAudio audio) => SessionViewModel(
      repository: rooms,
      audio: audio,
      syncRepository: sync,
      trackUri: Uri.parse('http://servidor:3000/track'),
    );

void main() {
  test('con la descarga fallida el receptor no abre el stream y puede reintentar', () async {
    final sync = _Sync();
    final audio = _FlakyAudio();
    final viewModel = _viewModel(_Rooms(), sync, audio);
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(viewModel.trackStatus, TrackStatus.failed);
    expect(viewModel.audioWarning, isNotNull);
    expect(sync.opened, 0);

    await viewModel.retryTrack();
    expect(viewModel.trackStatus, TrackStatus.ready);
    expect(viewModel.audioWarning, isNull);
    expect(audio.loads, 2);
    expect(sync.opened, 1);
  });

  test('sin la pista lista no arranca ni envía un ACK falso', () async {
    final sync = _Sync();
    final audio = _FlakyAudio(failures: 5);
    final startAt = DateTime.now().millisecondsSinceEpoch - 1000;
    final viewModel = _viewModel(_Rooms(playing: true, startAt: startAt), sync, audio);
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(viewModel.trackStatus, TrackStatus.failed);
    expect(audio.starts, 0);
    expect(sync.acks, isEmpty);
  });

  test('el volumen se guarda por participante y arranca en 0.8', () async {
    final viewModel = _viewModel(_Rooms(), _Sync(), _FlakyAudio(failures: 0));
    addTearDown(viewModel.dispose);

    expect(viewModel.volumeOf('rx'), 0.8);
    await viewModel.setReceiverVolume('rx', 0.3);
    expect(viewModel.volumeOf('rx'), 0.3);
    await viewModel.setReceiverVolume('rx', 4);
    expect(viewModel.volumeOf('rx'), 1.0);
  });
}
