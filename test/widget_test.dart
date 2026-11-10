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

/// Pantalla alta para que el formulario completo quede visible.
Future<void> _tallScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('muestra las acciones principales', (tester) async {
    await _tallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomePage(repository: FakeRepository())));
    expect(find.text('Unirme'), findsOneWidget);
    expect(find.text('Crear sala'), findsOneWidget);
    expect(find.byKey(const Key('codigo-sala')), findsOneWidget);
    expect(find.byKey(const Key('nombre')), findsOneWidget);
    expect(find.byKey(const Key('accion-principal')), findsOneWidget);
  });

  testWidgets('el código de la sala solo admite 6 dígitos', (tester) async {
    await _tallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomePage(repository: FakeRepository())));

    await tester.enterText(find.byKey(const Key('codigo-sala')), 'ab12cd3456789');

    final field = tester.widget<TextField>(find.byKey(const Key('codigo-sala')));
    expect(field.controller!.text, '123456');
  });

  testWidgets('pide el nombre antes de unirse', (tester) async {
    await _tallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomePage(repository: FakeRepository())));

    await tester.enterText(find.byKey(const Key('codigo-sala')), '123456');
    await tester.tap(find.byKey(const Key('accion-principal')));
    await tester.pump();

    expect(find.text('Escribe tu nombre para continuar.'), findsOneWidget);
  });

  testWidgets('pide un código completo antes de unirse', (tester) async {
    await _tallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomePage(repository: FakeRepository())));

    await tester.enterText(find.byKey(const Key('codigo-sala')), '123');
    await tester.enterText(find.byKey(const Key('nombre')), 'Ana');
    await tester.tap(find.byKey(const Key('accion-principal')));
    await tester.pump();

    expect(find.text('El código de la sala tiene 6 dígitos.'), findsOneWidget);
  });
}
