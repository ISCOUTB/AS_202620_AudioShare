/**
 * Configuración transversal del sistema.
 *
 * Este es el único lugar donde se lee `process.env`. Los módulos de dominio
 * (session, audio, sync) no deben leer variables de entorno directamente:
 * reciben su configuración desde aquí para mantener el límite de módulo.
 */
export const config = {
  port: Number(process.env.PORT ?? 3000),
  env: process.env.NODE_ENV ?? "development",
};
