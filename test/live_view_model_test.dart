import 'dart:async';

import 'package:audioshare/features/live/domain/live_audio_engine.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/viewmodels/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rooms implements RoomRepository {
  @override
  Future<String> createRoom(String emitterId) async => 'room-1';

  @override
  Future<String> joinRoom(String roomId, String receiverId) async => receiverId;

  @override
  Future<Room> getRoom(String roomId) async => Room(
        id: roomId,
        createdAt: DateTime(2026),
        status: PlaybackStatus.stopped,
        playing: false,
        positionMs: 0,
        startAt: null,
        participants: [
          Participant(id: 'ana', role: ParticipantRole.emitter, joinedAt: DateTime(2026)),
          Participant(id: 'luis', role: ParticipantRole.receiver, joinedAt: DateTime(2026)),
        ],
      );

  @override
  Future<Room> play(String roomId) => getRoom(roomId);

  @override
  Future<Room> pause(String roomId) => getRoom(roomId);
}

class _FakeEngine implements LiveAudioEngine {
  _FakeEngine({this.receive = true});

  final bool receive;
  final controller = StreamController<LiveEngineEvent>.broadcast(sync: true);
  final calls = <String>[];
  Object? startError;
  Uri? emitUrl;
  String? emitKey;
  CaptureSource? emitSource;
  double? emitOffset;
  Uri? receiveUrl;
  String? receiveId;
  double? volume;

  @override
  List<CaptureOption> get captureOptions => [
        const CaptureOption(source: CaptureSource.device, available: true),
        const CaptureOption(source: CaptureSource.app, available: false, reason: 'No en el navegador.'),
        const CaptureOption(source: CaptureSource.tab, available: true),
      ];

  @override
  bool get canReceive => receive;

  @override
  Stream<LiveEngineEvent> get events => controller.stream;

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> prepareReceiver() async => calls.add('prepareReceiver');

  @override
  Future<bool> unlock() async {
    calls.add('unlock');
    return true;
  }

  @override
  Future<void> startEmitting({
    required Uri url,
    required String emitterKey,
    required CaptureSource source,
    required double offsetMs,
  }) async {
    final error = startError;
    if (error != null) throw error;
    emitUrl = url;
    emitKey = emitterKey;
    emitSource = source;
    emitOffset = offsetMs;
  }

  @override
  Future<void> stopEmitting() async => calls.add('stopEmitting');

  @override
  void startReceiving({
    required Uri url,
    required String receiverId,
    required double offsetMs,
    int delayMs = 400,
  }) {
    receiveUrl = url;
    receiveId = receiverId;
  }

  @override
  void stopReceiving() => calls.add('stopReceiving');

  @override
  void setVolume(double value) => volume = value;

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await controller.close();
  }
}

SessionViewModel _viewModel(_FakeEngine engine) => SessionViewModel(
      repository: _Rooms(),
      live: engine,
      liveBaseUri: Uri.parse('https://audioshare.test'),
      emitterKeyFor: (roomId) => 'llave-$roomId',
    );

void main() {
  group('emisor', () {
    test('comparte una pestaña con la URL del WebSocket y la llave de la sala', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.createRoom('ana');
      await viewModel.prepareLive();
      expect(viewModel.liveEnabled, isTrue);
      expect(viewModel.captureOptions.map((option) => option.source), CaptureSource.values);

      await viewModel.startSharing(CaptureSource.tab);

      expect(engine.emitUrl.toString(), 'wss://audioshare.test/rooms/room-1/live');
      expect(engine.emitKey, 'llave-room-1');
      expect(engine.emitSource, CaptureSource.tab);
      expect(viewModel.liveState, LiveLinkState.connecting);
      expect(viewModel.isSharing, isTrue);

      engine.controller.add(const LiveStateEvent(LiveLinkState.sharing, source: 'tab', label: 'Una pestaña'));
      expect(viewModel.liveState, LiveLinkState.sharing);
      expect(viewModel.liveSource, CaptureSource.tab);

      engine.controller.add(const LiveStatsEvent(sent: 50, dropped: 0));
      expect(viewModel.liveStats?.sent, 50);
    });

    test('usa ws:// cuando el servidor es http', () async {
      final engine = _FakeEngine();
      final viewModel = SessionViewModel(
        repository: _Rooms(),
        live: engine,
        liveBaseUri: Uri.parse('http://192.168.1.10:3000'),
        emitterKeyFor: (_) => 'llave',
      );
      addTearDown(viewModel.dispose);

      await viewModel.createRoom('ana');
      await viewModel.startSharing(CaptureSource.device);

      expect(engine.emitUrl.toString(), 'ws://192.168.1.10:3000/rooms/room-1/live');
    });

    test('si el usuario cancela o el navegador falla, muestra el motivo y no queda compartiendo', () async {
      final engine = _FakeEngine()..startError = const LiveEngineException('Cancelaste la selección.');
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.createRoom('ana');
      await viewModel.startSharing(CaptureSource.tab);

      expect(viewModel.liveMessage, 'Cancelaste la selección.');
      expect(viewModel.liveState, LiveLinkState.idle);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.liveSource, isNull);
    });

    test('dejar de compartir detiene el motor pero la sala sigue abierta', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.createRoom('ana');
      await viewModel.startSharing(CaptureSource.device);
      await viewModel.stopSharing();

      expect(engine.calls, contains('stopEmitting'));
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.ended, isNull);
    });

    test('si el navegador corta la captura, vuelve a estado inactivo con aviso', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.createRoom('ana');
      await viewModel.startSharing(CaptureSource.tab);
      engine.controller.add(const LiveStateEvent(LiveLinkState.sharing, source: 'tab'));
      engine.controller.add(
        const LiveStateEvent(LiveLinkState.idle, message: 'Dejaste de compartir desde el navegador.'),
      );

      expect(viewModel.isSharing, isFalse);
      expect(viewModel.liveSource, isNull);
      expect(viewModel.liveMessage, contains('navegador'));
    });

    test('un receptor no puede empezar a compartir', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.joinRoom('room-1', 'luis');
      await viewModel.startSharing(CaptureSource.tab);

      expect(engine.emitUrl, isNull);
    });
  });

  group('receptor', () {
    test('se conecta al audio de la sala al entrar y refleja lo que comparte el emisor', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.prepareLive(receiver: true);
      await viewModel.joinRoom('room-1', 'luis');

      expect(engine.calls.first, 'prepareReceiver');
      expect(engine.receiveUrl.toString(), 'wss://audioshare.test/rooms/room-1/live');
      expect(engine.receiveId, 'luis');
      expect(viewModel.liveState, LiveLinkState.connecting);
      expect(viewModel.broadcasting, isFalse);

      engine.controller.add(const LiveStateEvent(LiveLinkState.waiting));
      engine.controller.add(const LiveBroadcastEvent(active: true, source: 'device', label: 'Todo el dispositivo'));
      expect(viewModel.broadcasting, isTrue);
      expect(viewModel.liveSource, CaptureSource.device);

      engine.controller.add(const LiveStateEvent(LiveLinkState.playing));
      expect(viewModel.liveState, LiveLinkState.playing);

      engine.controller.add(const LiveBroadcastEvent(active: false));
      expect(viewModel.broadcasting, isFalse);
      expect(viewModel.liveSource, isNull);
      expect(viewModel.liveState, LiveLinkState.waiting);
    });

    test('si el navegador bloquea el audio, un toque lo desbloquea', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.joinRoom('room-1', 'luis');
      engine.controller.add(const LiveStateEvent(LiveLinkState.blocked, message: 'Toca «Activar audio».'));
      expect(viewModel.liveState, LiveLinkState.blocked);

      await viewModel.unlockAudio();

      expect(engine.calls, contains('unlock'));
      expect(viewModel.liveState, LiveLinkState.waiting);
      expect(viewModel.liveMessage, isNull);
    });

    test('un dispositivo que no puede reproducir lo dice y no se conecta', () async {
      final engine = _FakeEngine(receive: false);
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.joinRoom('room-1', 'luis');

      expect(engine.receiveUrl, isNull);
      expect(viewModel.liveState, LiveLinkState.error);
      expect(viewModel.liveMessage, isNotNull);
    });

    test('el volumen llega al motor de audio en vivo', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.joinRoom('room-1', 'luis');
      await viewModel.setReceiverVolume('luis', 0.3);

      expect(engine.volume, closeTo(0.3, 1e-9));
    });

    test('al salir de la sala se detiene todo el audio', () async {
      final engine = _FakeEngine();
      final viewModel = _viewModel(engine);
      addTearDown(viewModel.dispose);

      await viewModel.joinRoom('room-1', 'luis');
      await viewModel.leaveRoom();

      expect(viewModel.ended, RoomEnd.left);
      expect(engine.calls, containsAll(['stopEmitting', 'stopReceiving']));
    });
  });
}
