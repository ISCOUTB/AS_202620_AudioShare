/**
 * Métrica mínima consultable, ligada al aspecto A-01 y a los escenarios de
 * calidad EC-01/EC-04 (docs/escenarios_calidad.md).
 *
 * Nota honesta, para no inflar lo que esto mide: el servidor push-only
 * (NDJSON) hoy NO recibe confirmación del receptor, así que no puede
 * calcular por sí solo la diferencia real en ms entre receptores que pide
 * EC-01 (≤100 ms) — eso requiere que el receptor reporte su propio
 * timestamp de arranque, lo cual el README ya declara como pendiente.
 * Mientras tanto, esta métrica expone lo que SÍ es verificable desde el
 * servidor: cuántas salas y reproducciones ocurrieron y con cuántos
 * receptores conectados en el momento del PLAY — un proxy operacional real,
 * no un placeholder inventado.
 *
 * Colócalo en src/shared/metrics.ts e impórtalo desde app.ts.
 */
export const metrics = {
  roomsCreated: 0,
  playEvents: 0,
  lastPlayReceiverCount: 0,
  lastPlayAt: null as string | null,
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
    nota: "Proxy operacional. La medición en ms de EC-01 requiere ack del " +
      "receptor (pendiente, ver README > Estado actual > Pendiente).",
  });
}
