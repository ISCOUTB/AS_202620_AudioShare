import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioshare/features/session/data/models/room.dart';
import 'package:audioshare/features/session/data/repositories/room_repository.dart';
import 'package:audioshare/features/session/presentation/pages/home_page.dart';

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
  testWidgets('muestra las acciones principales', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomePage(repository: FakeRepository())));
    expect(find.text('Crear sala'), findsOneWidget);
    expect(find.text('Unirse a sala'), findsOneWidget);
    expect(find.text('CREAR SALA'), findsOneWidget);
  });
}
