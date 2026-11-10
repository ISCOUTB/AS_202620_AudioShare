import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioshare/core/network/api_client.dart';
import 'package:audioshare/features/audio/data/audio_track_repository.dart';
import 'package:audioshare/features/audio/domain/audio_service.dart';
import 'package:audioshare/features/session/data/emitter_session_store.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_control_repository.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/viewmodels/session_view_model.dart';
import 'package:audioshare/features/sync/data/sync_event.dart';
import 'package:audioshare/features/sync/data/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rooms implements RoomRepository {
  bool playing = false;
  int? startAt;
  int trackVersion = 1;
  final receivers = <String>['rx'];

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
        trackName: 'Canción',
        trackVersion: trackVersion,
        participants: [
          Participant(id: 'host', role: ParticipantRole.emitter, joinedAt: DateTime(2026)),
          for (final id in receivers)
            Participant(id: id, role: ParticipantRole.receiver, joinedAt: DateTime(2026)),
        ],
      );
  @override
  Future<Room> play(String roomId) async {
    playing = true;
    startAt = 10500;
    return getRoom(roomId);
  }

  @override
  Future<Room> pause(String roomId) async {
    playing = false;
    return getRoom(roomId);
  }
}

class _Control implements RoomControlRepository {
  final left = <String>[];
  final kicked = <String>[];
  final closed = <String>[];
  final events = StreamController<SyncEvent>.broadcast();
  bool failLeave = false;

  @override
  Future<void> leave(String roomId, String receiverId) async {
    if (failLeave) throw const ApiException('sin red', kind: ApiFailureKind.connection);
    left.add('$roomId/$receiverId');
  }

  @override
  Future<void> kick(String roomId, String receiverId) async => kicked.add('$roomId/$receiverId');
  @override
  Future<void> closeRoom(String roomId) async => closed.add(roomId);
  @override
  Future<String> rejoinAsEmitter(String roomId, String emitterKey) async => 'host';
  @override
  Stream<SyncEvent> watch(String roomId) => events.stream;
}

class _Sync implements SyncRepository {
  _Sync(this.localClock);

  final int Function() localClock;
  int opened = 0;
  final acks = <int>[];
  final controller = StreamController<SyncEvent>.broadcast();

  @override
  Stream<SyncEvent> events(String roomId, String receiverId) {
    opened++;
    return controller.stream;
  }

  /// El reloj del servidor va 3000 ms por detrás del local.
  @override
  Future<int> serverTime() async => localClock() - 3000;

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

class _Audio extends MockAudioService {
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

class _Uploader implements AudioTrackRepository {
  final uploads = <String>[];

  @override
  Future<void> upload(String roomId, Uint8List bytes, {String? trackName}) async {
    uploads.add('$roomId/$trackName/${bytes.length}');
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('ApiClient y la llave de emisor', () {
    test('las peticiones de la sala propia llevan la llave; las demás no', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json({});
      });
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));
      api.emitterKeys['123456'] = 'secreta';

      await api.request('POST', '/rooms/123456/play', body: {});
      await api.request('POST', '/rooms/999999/play', body: {});
      await api.request('GET', '/time');

      expect(requests[0].headers['Authorization'], 'Bearer secreta');
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
      expect(requests[2].headers.containsKey('Authorization'), isFalse);
      client.close();
    });

    test('una respuesta 204 se acepta sin cuerpo', () async {
      final client = MockClient((request) async => http.Response('', 204));
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));

      final data = await api.request('DELETE', '/rooms/123456/receivers/Luis');

      expect(data, isEmpty);
      client.close();
    });

    test('la subida de la pista lleva la llave y el nombre codificado', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 201);
      });
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));
      api.emitterKeys['123456'] = 'secreta';

      await ApiAudioTrackRepository(api).upload(
        '123456',
        Uint8List.fromList([1, 2, 3]),
        trackName: 'Canción 1.mp3',
      );

      final request = requests.single;
      expect(request.headers['Authorization'], 'Bearer secreta');
      expect(request.headers['X-Track-Name'], Uri.encodeComponent('Canción 1.mp3'));
      client.close();
    });
  });

  group('repositorios', () {
    test('crear una sala registra la llave de emisor que entrega el servidor', () async {
      final client = MockClient(
        (request) async => _json({'roomId': '123456', 'emitterId': 'Ana', 'emitterKey': 'k1'}, 201),
      );
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));

      final roomId = await ApiRoomRepository(api).createRoom('Ana');

      expect(roomId, '123456');
      expect(api.emitterKeys['123456'], 'k1');
      client.close();
    });

    test('volver como emisor registra la llave solo si el servidor la acepta', () async {
      var status = 200;
      final client = MockClient((request) async {
        return status == 200
            ? _json({'roomId': '123456', 'emitterId': 'Ana', 'role': 'emitter'})
            : _json({'error': 'La llave de emisor no es válida para esta sala'}, status);
      });
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));
      final control = ApiRoomControlRepository(api);

      expect(await control.rejoinAsEmitter('123456', 'buena'), 'Ana');
      expect(api.emitterKeys['123456'], 'buena');

      status = 403;
      await expectLater(
        control.rejoinAsEmitter('654321', 'mala'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
      expect(api.emitterKeys.containsKey('654321'), isFalse);
      client.close();
    });

    test('salir, expulsar y cerrar usan los endpoints del servidor', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      });
      final api = ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test'));
      final control = ApiRoomControlRepository(api);

      await control.leave('123456', 'Luis');
      await control.kick('123456', 'Luis');
      await control.closeRoom('123456');

      expect(requests[0].method, 'DELETE');
      expect(requests[0].url.path, '/rooms/123456/receivers/Luis');
      expect(requests[1].method, 'POST');
      expect(requests[1].url.path, '/rooms/123456/kick');
      expect(jsonDecode(requests[1].body), {'receiverId': 'Luis'});
      expect(requests[2].method, 'DELETE');
      expect(requests[2].url.path, '/rooms/123456');
      client.close();
    });
  });

  group('modelos y eventos', () {
    test('Room y Participant leen nombre de canción, versión y conexión', () {
      final room = Room.fromJson({
        'roomId': '123456',
        'createdAt': '2026-01-01T00:00:00Z',
        'status': 'stopped',
        'playbackState': {'playing': false, 'positionMs': 0},
        'startAt': null,
        'trackName': 'Mi canción.mp3',
        'trackVersion': 2,
        'participants': [
          {'id': 'Ana', 'role': 'emitter', 'joinedAt': '2026-01-01T00:00:00Z'},
          {'id': 'Luis', 'role': 'receiver', 'joinedAt': '2026-01-01T00:00:00Z', 'connected': true},
        ],
        'connectedReceivers': 1,
      });

      expect(room.trackName, 'Mi canción.mp3');
      expect(room.trackVersion, 2);
      expect(room.participants.first.connected, isFalse);
      expect(room.participants.last.connected, isTrue);
    });

    test('interpreta los eventos de participantes, pista y cierre', () {
      final joined = SyncEvent.parse(
        '{"type":"participant.joined","participant":{"id":"Luis","role":"receiver"}}',
      );
      expect(joined, isA<ParticipantEvent>());
      expect((joined as ParticipantEvent).change, ParticipantChange.joined);
      expect(joined.participantId, 'Luis');

      final removed = SyncEvent.parse(
        '{"type":"participant.left","receiverId":"Luis","reason":"removed"}',
      ) as ParticipantEvent;
      expect(removed.change, ParticipantChange.left);
      expect(removed.removed, isTrue);

      final left = SyncEvent.parse(
        '{"type":"participant.left","receiverId":"Luis","reason":"left"}',
      ) as ParticipantEvent;
      expect(left.removed, isFalse);

      final connected = SyncEvent.parse('{"type":"participant.connected","receiverId":"Luis"}');
      expect((connected as ParticipantEvent).change, ParticipantChange.connected);

      final track = SyncEvent.parse('{"type":"track.changed","trackName":"Otra","trackVersion":3}');
      expect((track as TrackChangedEvent).trackName, 'Otra');
      expect(track.trackVersion, 3);

      expect(SyncEvent.parse('{"type":"room.closed"}'), isA<RoomClosedEvent>());
      expect(SyncEvent.parse('{"type":"track.changed"}'), isNull);
    });
  });

  group('sesión del emisor guardada', () {
    test('en memoria: guarda, lee y borra', () async {
      final store = MemoryEmitterSessionStore();
      expect(await store.load(), isNull);

      await store.save(const EmitterSession(roomId: '123456', emitterId: 'Ana', emitterKey: 'k'));
      final session = await store.load();
      expect(session?.roomId, '123456');
      expect(session?.emitterKey, 'k');

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('con SharedPreferences: guarda, lee y borra', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesEmitterSessionStore();
      expect(await store.load(), isNull);

      await store.save(const EmitterSession(roomId: '123456', emitterId: 'Ana', emitterKey: 'k'));
      final session = await store.load();
      expect(session?.emitterId, 'Ana');
      expect(session?.emitterKey, 'k');

      await store.clear();
      expect(await store.load(), isNull);
    });
  });

  group('SessionViewModel: salir, expulsar y eventos', () {
    test('un receptor que sale avisa al servidor y termina su estancia', () async {
      final control = _Control();
      final viewModel = SessionViewModel(repository: _Rooms(), control: control);
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');

      await viewModel.leaveRoom();

      expect(control.left, ['room-1/rx']);
      expect(viewModel.ended, RoomEnd.left);
    });

    test('salir no falla aunque no haya red', () async {
      final control = _Control()..failLeave = true;
      final viewModel = SessionViewModel(repository: _Rooms(), control: control);
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');

      await viewModel.leaveRoom();

      expect(viewModel.ended, RoomEnd.left);
      expect(viewModel.error, isNull);
    });

    test('el emisor que sale no quita su sala', () async {
      final control = _Control();
      final viewModel = SessionViewModel(repository: _Rooms(), control: control);
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');
      expect(viewModel.isEmitter, isTrue);

      await viewModel.leaveRoom();

      expect(control.left, isEmpty);
      expect(control.closed, isEmpty);
      expect(viewModel.ended, RoomEnd.left);
    });

    test('el emisor cierra la sala para todos', () async {
      final control = _Control();
      final viewModel = SessionViewModel(repository: _Rooms(), control: control);
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');

      await viewModel.closeRoom();

      expect(control.closed, ['room-1']);
      expect(viewModel.ended, RoomEnd.closed);
    });

    test('un receptor no puede expulsar ni cerrar', () async {
      final control = _Control();
      final viewModel = SessionViewModel(repository: _Rooms(), control: control);
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');

      await viewModel.kick('otro');
      await viewModel.closeRoom();

      expect(control.kicked, isEmpty);
      expect(control.closed, isEmpty);
      expect(viewModel.ended, isNull);
    });

    test('el emisor expulsa a un receptor y la lista se actualiza', () async {
      final rooms = _Rooms();
      final control = _Control();
      final viewModel = SessionViewModel(repository: rooms, control: control);
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');
      expect(viewModel.room!.participants.map((p) => p.id), contains('rx'));

      rooms.receivers.remove('rx');
      await viewModel.kick('rx');

      expect(control.kicked, ['room-1/rx']);
      expect(viewModel.room!.participants.map((p) => p.id), isNot(contains('rx')));
    });

    test('el emisor ve entrar y salir gente por los eventos de la sala', () async {
      final rooms = _Rooms();
      final control = _Control();
      final viewModel = SessionViewModel(repository: rooms, control: control);
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');

      rooms.receivers.add('nuevo');
      control.events.add(const ParticipantEvent(ParticipantChange.joined, 'nuevo'));
      await pumpEventQueue();
      expect(viewModel.room!.participants.map((p) => p.id), contains('nuevo'));

      rooms.receivers.remove('nuevo');
      control.events.add(const ParticipantEvent(ParticipantChange.left, 'nuevo'));
      await pumpEventQueue();
      expect(viewModel.room!.participants.map((p) => p.id), isNot(contains('nuevo')));
    });

    test('un receptor expulsado se entera y termina su estancia', () async {
      final sync = _Sync(() => 0);
      final viewModel = SessionViewModel(repository: _Rooms(), syncRepository: sync, clock: () => 0);
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');

      sync.controller.add(const ParticipantEvent(ParticipantChange.left, 'otro', removed: true));
      await pumpEventQueue();
      expect(viewModel.ended, isNull);

      sync.controller.add(const ParticipantEvent(ParticipantChange.left, 'rx', removed: true));
      await pumpEventQueue();
      expect(viewModel.ended, RoomEnd.removed);
    });

    test('si el emisor cierra la sala, el receptor se entera', () async {
      final sync = _Sync(() => 0);
      final viewModel = SessionViewModel(repository: _Rooms(), syncRepository: sync, clock: () => 0);
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');

      sync.controller.add(const RoomClosedEvent());
      await pumpEventQueue();

      expect(viewModel.ended, RoomEnd.closed);
    });

    test('el emisor no abre el stream de los receptores', () async {
      final sync = _Sync(() => 0);
      final viewModel = SessionViewModel(
        repository: _Rooms(),
        syncRepository: sync,
        control: _Control(),
        trackUri: Uri.parse('http://servidor:3000/track'),
        clock: () => 0,
      );
      addTearDown(viewModel.dispose);

      await viewModel.restoreEmitter('room-1', 'host');
      expect(viewModel.trackStatus, TrackStatus.ready);
      await viewModel.retryTrack();

      expect(viewModel.isEmitter, isTrue);
      expect(sync.opened, 0);
      expect(viewModel.ended, isNull);
    });
  });

  group('SessionViewModel: canción', () {
    test('al cambiar la canción el receptor descarga la nueva', () async {
      final rooms = _Rooms();
      final sync = _Sync(() => 0);
      final audio = _Audio();
      final viewModel = SessionViewModel(
        repository: rooms,
        syncRepository: sync,
        audio: audio,
        trackUri: Uri.parse('http://servidor:3000/track'),
        clock: () => 0,
      );
      addTearDown(viewModel.dispose);
      await viewModel.joinRoom('room-1', 'rx');
      expect(audio.calls.where((call) => call.startsWith('load:')), hasLength(1));

      rooms.trackVersion = 2;
      sync.controller.add(const TrackChangedEvent('Otra', 2));
      await pumpEventQueue();

      expect(audio.calls.where((call) => call.startsWith('load:')), hasLength(2));
      expect(audio.pauses, greaterThanOrEqualTo(1));
      expect(viewModel.room!.trackVersion, 2);
    });

    test('el emisor cambia la canción: sube el archivo y la recarga', () async {
      final rooms = _Rooms();
      final audio = _Audio();
      final uploader = _Uploader();
      final viewModel = SessionViewModel(
        repository: rooms,
        audio: audio,
        control: _Control(),
        trackRepository: uploader,
        trackUri: Uri.parse('http://servidor:3000/track'),
      );
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');

      rooms.trackVersion = 2;
      await viewModel.changeTrack(Uint8List.fromList([1, 2, 3]), 'Nueva.mp3');

      expect(uploader.uploads, ['room-1/Nueva.mp3/3']);
      expect(audio.calls, contains('load:http://servidor:3000/rooms/room-1/track'));
      expect(viewModel.trackStatus, TrackStatus.ready);
    });

    test('el emisor oye la pista en el mismo startAt, sin enviar ACK', () async {
      var local = 13000;
      final waits = <Duration>[];
      final sync = _Sync(() => local);
      final audio = _Audio();
      final viewModel = SessionViewModel(
        repository: _Rooms(),
        syncRepository: sync,
        audio: audio,
        control: _Control(),
        trackUri: Uri.parse('http://servidor:3000/track'),
        clock: () => local,
        wait: (duration) async {
          waits.add(duration);
          local += duration.inMilliseconds;
        },
      );
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');
      await viewModel.prepareOwnTrack();
      expect(viewModel.trackStatus, TrackStatus.ready);

      await viewModel.play();

      // startAt 10500 en el reloj del servidor = 13500 en el local.
      expect(waits, [const Duration(milliseconds: 500)]);
      expect(audio.starts, 1);
      expect(sync.acks, isEmpty);
    });

    test('al pausar, el emisor se coloca en la posición del servidor', () async {
      final audio = _Audio();
      final viewModel = SessionViewModel(repository: _Rooms(), audio: audio, control: _Control());
      addTearDown(viewModel.dispose);
      await viewModel.createRoom('host');

      await viewModel.pause();

      expect(audio.pauses, 1);
      expect(audio.calls, contains('seek:0'));
    });
  });
}
