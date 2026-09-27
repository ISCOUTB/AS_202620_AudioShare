/**
 * Logger estructurado mínimo.
 *
 * No añade una dependencia nueva (pino/winston) para no tocar el árbol de
 * dependencias en la semana de despliegue; si el equipo prefiere pino,
 * el cambio es intercambiar este archivo — el resto del código ya llama
 * a `log.info(...)`, no a `console.log`.
 *
 * Cada línea es un JSON: nivel, mensaje, timestamp ISO y campos extra.
 * Ejemplo de línea real que emite este módulo:
 *   {"level":"info","msg":"room.created","ts":"2026-09-27T14:03:22.104Z","roomId":"a1b2c3"}
 *
 * Colócalo en src/shared/logger.ts.
 */
type Level = "info" | "warn" | "error";

function write(level: Level, msg: string, fields: Record<string, unknown> = {}) {
  const line = {
    level,
    msg,
    ts: new Date().toISOString(),
    ...fields,
  };
  // stdout: así es como lo recoge cualquier plataforma (Render, Fly, el
  // servidor del laboratorio con journald/docker logs) sin configuración
  // adicional.
  process.stdout.write(JSON.stringify(line) + "\n");
}

export const log = {
  info: (msg: string, fields?: Record<string, unknown>) => write("info", msg, fields),
  warn: (msg: string, fields?: Record<string, unknown>) => write("warn", msg, fields),
  error: (msg: string, fields?: Record<string, unknown>) => write("error", msg, fields),
};
