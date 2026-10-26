import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/audio/domain/audio_service.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/viewmodels/session_view_model.dart';
import 'package:audioshare/features/sync/data/sync_event.dart';
import 'package:audioshare/features/sync/data/sync_repository.dart';

class _Rooms implements RoomRepository {
  _Rooms({required this.playing, required this.startAt});

  bool playing;
  int? startAt;

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
  _Sync(this.localClock, {this.failTime = false});

  /// Reloj local simulado, 3000 ms adelantado respecto al servidor.
  final int Function() localClock;
  final bool failTime;
  final acks = <Map<String, num>>[];
  final controller = StreamController<SyncEvent>.broadcast();

  @override
  Stream<SyncEvent> events(String roomId, String receiverId) => controller.stream;

  @override
  Future<int> serverTime() async {
    if (failTime) throw Exception('sin red');
    return localClock() - 3000;
  }

  @override
  Future<void> ackStart({
    required String roomId,
    required String receiverId,
    required int startedAt,
    required double offsetMs,
  }) async {
    acks.add({'startedAt': startedAt, 'offsetMs': offsetMs});
  }
}

class _CountingAudio extends MockAudioService {
  int starts = 0;
  int pauses = 0;
  final calls = <String>[];
  @override
  Future<void> load(String url) async => calls.add('load:$url');
  @override
  Future<void> seek(int positionMs) async => calls.add('seek:$positionMs');
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> pause() async => pauses++;
}

void main() {
  test('el receptor calibra el reloj, espera hasta startAt y envía el ACK una sola vez', () async {
    var local = 13000;
    final waits = <Duration>[];
    final rooms = _Rooms(playing: false, startAt: null);
    final sync = _Sync(() => local);
    final audio = _CountingAudio();
    final viewModel = SessionViewModel(
      repository: rooms,
      audio: audio,
      syncRepository: sync,
      clock: () => local,
      wait: (d) async {
        waits.add(d);
        local += d.inMilliseconds;
      },
    );
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(viewModel.clockOffsetMs, -3000);
    expect(viewModel.calibrationWarning, isNull);

    // El emisor inicia: startAt 10500 en reloj del servidor = 13500 en el local.
    rooms
      ..playing = true
      ..startAt = 10500;
    await viewModel.refresh();

    expect(waits, [const Duration(milliseconds: 500)]);
    expect(audio.starts, 1);
    expect(sync.acks, hasLength(1));
    expect(sync.acks.single['startedAt'], 13500);
    expect(sync.acks.single['offsetMs'], -3000);

    // Mismo startAt: no se vuelve a arrancar ni a enviar ACK.
    await viewModel.refresh();
    expect(sync.acks, hasLength(1));
    expect(audio.starts, 1);
  });

  test('si startAt ya pasó, arranca de inmediato sin esperar', () async {
    var local = 20000;
    final waits = <Duration>[];
    final rooms = _Rooms(playing: true, startAt: 10500);
    final sync = _Sync(() => local);
    final audio = _CountingAudio();
    final viewModel = SessionViewModel(
      repository: rooms,
      audio: audio,
      syncRepository: sync,
      trackUri: Uri.parse('http://servidor:3000/track'),
      clock: () => local,
      wait: (d) async => waits.add(d),
    );
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    await viewModel.refresh();

    expect(waits, isEmpty);
    expect(audio.calls, contains('load:http://servidor:3000/rooms/room-1/track'));
    expect(audio.calls, contains('seek:6500'));
    expect(audio.starts, 1);
    expect(sync.acks, hasLength(1));
  });

  test('si /time falla, el receptor sigue en la sala con un aviso y no envía ACK', () async {
    final rooms = _Rooms(playing: true, startAt: 10500);
    final sync = _Sync(() => 0, failTime: true);
    final viewModel = SessionViewModel(repository: rooms, syncRepository: sync, clock: () => 0, wait: (_) async {});
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(viewModel.error, isNull);
    expect(viewModel.room, isNotNull);
    expect(viewModel.clockOffsetMs, isNull);
    expect(viewModel.calibrationWarning, isNotNull);

    await viewModel.refresh();
    expect(sync.acks, isEmpty);
  });

  test('sin SyncRepository el comportamiento no cambia', () async {
    final rooms = _Rooms(playing: true, startAt: 10500);
    final viewModel = SessionViewModel(repository: rooms);
    addTearDown(viewModel.dispose);
    await viewModel.joinRoom('room-1', 'rx');
    await viewModel.refresh();
    expect(viewModel.error, isNull);
    expect(viewModel.clockOffsetMs, isNull);
  });
  test('el receptor arranca al recibir sync.start por el stream, sin refrescar la sala', () async {
    var local = 13000;
    final waits = <Duration>[];
    final rooms = _Rooms(playing: false, startAt: null);
    final sync = _Sync(() => local);
    final audio = _CountingAudio();
    final viewModel = SessionViewModel(
      repository: rooms,
      audio: audio,
      syncRepository: sync,
      clock: () => local,
      wait: (d) async {
        waits.add(d);
        local += d.inMilliseconds;
      },
    );
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');

    rooms
      ..playing = true
      ..startAt = 10500;
    sync.controller.add(const SyncStartEvent(10500));
    await pumpEventQueue();

    expect(waits, [const Duration(milliseconds: 500)]);
    expect(audio.starts, 1);
    expect(sync.acks, hasLength(1));
    expect(sync.acks.single['startedAt'], 13500);
    expect(viewModel.room?.startAt, 10500);

    // El mismo startAt repetido (o una actualización posterior) no duplica el ACK.
    sync.controller.add(const SyncStartEvent(10500));
    await pumpEventQueue();
    await viewModel.refresh();
    expect(sync.acks, hasLength(1));
    expect(audio.starts, 1);

    // sync.pause detiene el audio y actualiza la sala.
    rooms.playing = false;
    sync.controller.add(const SyncPauseEvent(0));
    await pumpEventQueue();
    expect(audio.pauses, 1);
    expect(viewModel.room?.playing, isFalse);
  });

  test('el receptor descarga la pista al unirse y reanuda desde la posición del evento', () async {
    var local = 13000;
    final rooms = _Rooms(playing: false, startAt: null);
    final sync = _Sync(() => local);
    final audio = _CountingAudio();
    final viewModel = SessionViewModel(
      repository: rooms,
      audio: audio,
      syncRepository: sync,
      trackUri: Uri.parse('http://servidor:3000/track'),
      clock: () => local,
      wait: (d) async => local += d.inMilliseconds,
    );
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(audio.calls.first, 'load:http://servidor:3000/rooms/room-1/track');
    expect(viewModel.audioWarning, isNull);

    rooms
      ..playing = true
      ..startAt = 10500;
    sync.controller.add(const SyncStartEvent(10500, positionMs: 3000));
    await pumpEventQueue();

    // La pista se coloca en 3000 ms antes de arrancar.
    expect(audio.calls, contains('seek:3000'));
    expect(audio.starts, 1);
  });

  test('si la pista no se puede descargar, el receptor sigue en la sala con un aviso', () async {
    final audio = _FailingLoadAudio();
    final viewModel = SessionViewModel(
      repository: _Rooms(playing: false, startAt: null),
      audio: audio,
      syncRepository: _Sync(() => 13000),
      trackUri: Uri.parse('http://servidor:3000/track'),
      clock: () => 13000,
    );
    addTearDown(viewModel.dispose);

    await viewModel.joinRoom('room-1', 'rx');
    expect(viewModel.error, isNull);
    expect(viewModel.audioWarning, isNotNull);
  });
}

class _FailingLoadAudio extends MockAudioService {
  @override
  Future<void> load(String url) async => throw Exception('sin red');
}
