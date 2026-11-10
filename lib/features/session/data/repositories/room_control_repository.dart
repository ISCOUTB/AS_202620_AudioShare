import '../../../../core/network/api_client.dart';
import '../../../sync/data/sync_event.dart';

/// Acciones de sala que van más allá de entrar y reproducir: salir, expulsar,
/// cerrar la sala y volver como emisor (ADR-0014). Es una interfaz aparte de
/// [RoomRepository] para no obligar a quien ya la implementa a añadir métodos.
abstract interface class RoomControlRepository {
  /// Un receptor deja la sala.
  Future<void> leave(String roomId, String receiverId);

  /// El emisor expulsa a un receptor (el servidor veta su nombre en la sala).
  Future<void> kick(String roomId, String receiverId);

  /// El emisor cierra la sala para todos.
  Future<void> closeRoom(String roomId);

  /// Comprueba la llave guardada y devuelve el identificador del emisor. Si la
  /// llave no sirve, lanza [ApiException] y no la deja registrada.
  Future<String> rejoinAsEmitter(String roomId, String emitterKey);

  /// Eventos de la sala para el emisor (quién entra, sale, se conecta...).
  Stream<SyncEvent> watch(String roomId);
}

class ApiRoomControlRepository implements RoomControlRepository {
  ApiRoomControlRepository(this._api);

  final ApiClient _api;

  String _room(String roomId) => '/rooms/${Uri.encodeComponent(roomId)}';

  @override
  Future<void> leave(String roomId, String receiverId) => _api.request(
        'DELETE',
        '${_room(roomId)}/receivers/${Uri.encodeComponent(receiverId)}',
      );

  @override
  Future<void> kick(String roomId, String receiverId) => _api.request(
        'POST',
        '${_room(roomId)}/kick',
        body: {'receiverId': receiverId},
      );

  @override
  Future<void> closeRoom(String roomId) => _api.request('DELETE', _room(roomId));

  @override
  Future<String> rejoinAsEmitter(String roomId, String emitterKey) async {
    _api.emitterKeys[roomId] = emitterKey;
    try {
      final data = await _api.request('POST', '${_room(roomId)}/emitter');
      return data['emitterId'] as String;
    } catch (_) {
      _api.emitterKeys.remove(roomId);
      rethrow;
    }
  }

  @override
  Stream<SyncEvent> watch(String roomId) => _api
      .openLines('${_room(roomId)}/events')
      .map(SyncEvent.parse)
      .where((event) => event != null)
      .map((event) => event!);
}
