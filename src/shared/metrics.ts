/**
 * Métricas consultables, ligadas al aspecto A-01 y a los escenarios de
 * calidad EC-01/EC-04 (docs/escenarios_calidad.md).
 *
 * Qué mide cada grupo (para no inflar lo que significa):
 *  - rooms/play/last_play_receiver_count: proxy operacional del servidor.
 *  - last_sync_spread_ms / max_sync_spread_ms: desfase de arranque entre
 *    receptores (EC-01), calculado con los ACK que los propios receptores
 *    reportan (POST /rooms/:id/receivers/:rid/ack). Con receptores
 *    simulados mide el protocolo; con dispositivos reales mediría además la
 *    reproducción, pero esa medición física sigue pendiente.
 */
export const metrics = {
  roomsCreated: 0,
  playEvents: 0,
  lastPlayReceiverCount: 0,
  lastPlayAt: null as string | null,
  // Medición real de EC-01: diferencia entre el primer y el último receptor
  // en arrancar, calculada a partir de los ACK (POST .../ack).
  lastSyncSpreadMs: null as number | null,
  maxSyncSpreadMs: null as number | null,
};

export function metricsHandler(_req: unknown, res: {
  status: (code: number) => { json: (body: unknown) => void };
}) {
  res.status(200).json({
    aspecto: "A-01",
    escenarios_relacionados: ["EC-01", "EC-04"],
    rooms_created_total: metrics.roomsCreated,
    play_events_total: metrics.playEvents,
    last_play_receiver_count: metrics.lastPlayReceiverCount,
    last_play_at: metrics.lastPlayAt,
    last_sync_spread_ms: metrics.lastSyncSpreadMs,
    max_sync_spread_ms: metrics.maxSyncSpreadMs,
    nota: "last_sync_spread_ms es la diferencia de arranque entre receptores " +
      "calculada con los ACK que ellos reportan (EC-01, umbral 100 ms). " +
      "Es null mientras no haya al menos dos ACK. Con receptores simulados " +
      "mide el protocolo, no la reproducción física.",
  });
}
