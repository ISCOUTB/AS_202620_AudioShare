/**
 * Módulo: sync
 *
 * Responsabilidad (ver docs/adr/0001-usar-monolito-modular.md y
 * docs/Matriz_Comparativa.md): coordinar el momento en que cada
 * dispositivo receptor inicia, pausa o reanuda la reproducción, de modo
 * que se cumplan los escenarios de calidad EC-01 a EC-04
 * (docs/escenarios_calidad.md).
 *
 * Este módulo NO transmite el audio en sí (eso vive en `audio`) ni
 * administra quién está en la sesión (eso vive en `session`). Otros
 * módulos solo deben importar lo que este archivo exporte
 * explícitamente — nunca archivos internos de `sync/`.
 *
 * Semana 3: solo el límite del módulo. La lógica llega en semanas
 * posteriores, ligada al aspecto A-01 de docs/aspectos.md.
 */

export const syncModuleName = "sync" as const;
