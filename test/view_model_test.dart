import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/viewmodels/session_view_model.dart';

class FakeRepository implements RoomRepository {
  @override
  Future<String> createRoom(String emitterId) async => 'room-123';
  @override
  Future<String> joinRoom(String roomId, String receiverId) async => receiverId;
  @override
  Future<Room> getRoom(String roomId) async => Room(id: roomId, createdAt: DateTime.now(), status: PlaybackStatus.stopped, playing: false, positionMs: 0, startAt: null, participants: const []);
  @override
  Future<Room> play(String roomId) => getRoom(roomId);
  @override
  Future<Room> pause(String roomId) => getRoom(roomId);
}

void main() {
  test('ViewModel crea una sala mediante el repositorio', () async {
    final viewModel = SessionViewModel(repository: FakeRepository());
    await viewModel.createRoom('emitter');
    expect(viewModel.room?.id, 'room-123');
    expect(viewModel.error, isNull);
  });
}
