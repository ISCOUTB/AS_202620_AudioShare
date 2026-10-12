import '../../../../core/network/api_client.dart';
import '../models/room.dart';

// NOTA: reconstruido a partir de los usos en SessionViewModel, HomePage, los
// tests y los endpoints de docs/contracts/openapi.yaml (ver room.dart).

abstract interface class RoomRepository {
  /// Crea una sala y devuelve su identificador.
  Future<String> createRoom(String emitterId);

  /// Une un receptor a la sala y devuelve el identificador del receptor.
  Future<String> joinRoom(String roomId, String receiverId);

  Future<Room> getRoom(String roomId);

  Future<Room> play(String roomId);

  Future<Room> pause(String roomId);
}

class ApiRoomRepository implements RoomRepository {
  ApiRoomRepository(this._api);

  final ApiClient _api;

  @override
  Future<String> createRoom(String emitterId) async {
    final data = await _api.request('POST', '/rooms', body: {'emitterId': emitterId});
    return data['roomId'] as String;
  }

  @override
  Future<String> joinRoom(String roomId, String receiverId) async {
    final data = await _api.request(
      'POST',
      '/rooms/$roomId/receivers',
      body: {'receiverId': receiverId},
    );
    return data['receiverId'] as String;
  }

  @override
  Future<Room> getRoom(String roomId) async =>
      Room.fromJson(await _api.request('GET', '/rooms/$roomId'));

  // PlayResponse y PauseResponse no incluyen createdAt ni connectedReceivers,
  // así que se vuelve a consultar el estado completo de la sala.
  @override
  Future<Room> play(String roomId) async {
    await _api.request('POST', '/rooms/$roomId/play', body: {});
    return getRoom(roomId);
  }

  @override
  Future<Room> pause(String roomId) async {
    await _api.request('POST', '/rooms/$roomId/pause', body: {});
    return getRoom(roomId);
  }
}
