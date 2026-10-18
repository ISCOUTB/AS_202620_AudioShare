import '../../../core/network/api_client.dart';
import 'sync_event.dart';

/// Acceso a los endpoints de sincronización del backend (ADR-0007):
/// `GET /time` y `POST /rooms/{id}/receivers/{rid}/ack`.
abstract interface class SyncRepository {
  /// Reloj del servidor (epoch ms).
  Future<int> serverTime();

  /// Stream de eventos del receptor. Termina (o falla) si se corta la conexión.
  Stream<SyncEvent> events(String roomId, String receiverId);

  /// Informa cuándo empezó a reproducir el receptor, en su reloj LOCAL
  /// ([startedAt]), y el offset de reloj que estimó ([offsetMs]).
  Future<void> ackStart({
    required String roomId,
    required String receiverId,
    required int startedAt,
    required double offsetMs,
  });
}

class ApiSyncRepository implements SyncRepository {
  ApiSyncRepository(this._api);

  final ApiClient _api;

  @override
  Future<int> serverTime() async {
    final data = await _api.request('GET', '/time');
    return (data['serverTime'] as num).toInt();
  }

  @override
  Stream<SyncEvent> events(String roomId, String receiverId) => _api
      .openLines('/rooms/$roomId/stream/$receiverId')
      .map(SyncEvent.parse)
      .where((event) => event != null)
      .map((event) => event!);

  @override
  Future<void> ackStart({
    required String roomId,
    required String receiverId,
    required int startedAt,
    required double offsetMs,
  }) async {
    await _api.request(
      'POST',
      '/rooms/$roomId/receivers/$receiverId/ack',
      body: {'startedAt': startedAt, 'offsetMs': offsetMs},
    );
  }
}
