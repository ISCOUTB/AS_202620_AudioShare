/**
 * Configuración transversal del sistema.
 *
 * Este es el único lugar donde se lee `process.env`. Los módulos de dominio
 * (session, audio, sync) no deben leer variables de entorno directamente:
 * reciben su configuración desde aquí para mantener el límite de módulo.
 */
const env = process.env.NODE_ENV ?? "development";
const codespaceName = process.env.CODESPACE_NAME;
const defaultCorsOrigins = env === "production"
  ? ["https://audioshare.iscoutb.dev"]
  : [
      "http://localhost:3000",
      "http://localhost:8080",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:8080",
      ...(codespaceName
        ? [
            `https://${codespaceName}-3000.app.github.dev`,
            `https://${codespaceName}-8080.app.github.dev`,
          ]
        : []),
    ];

/** Horas sin actividad tras las cuales una sala (y su pista) se borra. 0 = nunca. */
function parseTtlHours(value: string | undefined): number {
  const hours = Number(value ?? 24);

  return Number.isFinite(hours) && hours >= 0 ? hours : 24;
}

/**
 * Saltos de proxy de confianza para que `req.ip` sea la IP del cliente y no la
 * del proxy (Traefik en Dokploy). Sin definir, Express usa la IP del vecino.
 */
function parseTrustProxy(value: string | undefined): number | boolean | undefined {
  if (value === undefined || value.trim() === "") {
    return undefined;
  }

  if (value === "true") {
    return true;
  }

  const hops = Number(value);

  return Number.isInteger(hops) && hops >= 0 ? hops : undefined;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  env,
  roomTtlMs: parseTtlHours(process.env.ROOM_TTL_HOURS) * 60 * 60 * 1000,
  trustProxy: parseTrustProxy(process.env.TRUST_PROXY),
  // GET /rooms enumera todas las salas (AM-02): en producción queda cerrado
  // salvo que se active a propósito.
  exposeRoomList: process.env.EXPOSE_ROOM_LIST === "true" || env !== "production",
  databaseFile: process.env.DATABASE_FILE ?? "data/audioshare.sqlite",
  corsOrigins: [
    ...new Set([
      ...defaultCorsOrigins,
      ...(process.env.CORS_ORIGINS ?? "")
        .split(",")
        .map((origin) => origin.trim())
        .filter(Boolean),
    ]),
  ],
};
