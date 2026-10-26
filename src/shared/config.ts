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

export const config = {
  port: Number(process.env.PORT ?? 3000),
  env,
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
