/**
 * Módulo: session
 *
 * Responsabilidad (ver docs/adr/0001-usar-monolito-modular.md y
 * docs/Matriz_Comparativa.md): gestionar las salas de transmisión y los
 * roles de sus participantes (emisor, receptor, moderador) — quién puede
 * iniciar una sesión, quién se une y quién administra a los participantes.
 *
 * Este módulo NO conoce el transporte de audio (eso vive en `audio`) ni
 * el algoritmo de sincronización de reproducción (eso vive en `sync`).
 * Otros módulos solo deben importar lo que este archivo exporte
 * explícitamente — nunca archivos internos de `session/`.
 *
 * Semana 3: solo el límite del módulo. La lógica llega en semanas
 * posteriores, ligada a los aspectos de docs/aspectos.md.
 */

export const sessionModuleName = "session" as const;
