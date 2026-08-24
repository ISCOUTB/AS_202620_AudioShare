/**
 * Módulo: audio
 *
 * Responsabilidad (ver docs/adr/0001-usar-monolito-modular.md y
 * docs/Matriz_Comparativa.md): captura, empaquetado y transmisión del
 * audio desde el dispositivo emisor hacia los dispositivos receptores
 * conectados a la misma red Wi-Fi.
 *
 * Este módulo NO decide quién pertenece a una sesión (eso vive en
 * `session`) ni cuándo cada receptor debe iniciar la reproducción (eso
 * vive en `sync`). Otros módulos solo deben importar lo que este archivo
 * exporte explícitamente — nunca archivos internos de `audio/`.
 *
 * Semana 3: solo el límite del módulo. La lógica llega en semanas
 * posteriores, ligada a los aspectos de docs/aspectos.md.
 */

export const audioModuleName = "audio" as const;
