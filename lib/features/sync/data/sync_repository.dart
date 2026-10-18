import '../../../core/network/api_client.dart';

/// Acceso a los endpoints de sincronización del backend (ADR-0007):
/// `GET /time` y `POST /rooms/{id}/receivers/{rid}/ack`.
abstract interface class SyncRepository {
  /// Reloj del servidor (epoch ms).
  Future<int> serverTime();

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
