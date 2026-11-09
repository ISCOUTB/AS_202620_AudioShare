# ADR-0014 — Llave de emisor, salida, expulsión y cambio de pista

- **Estado:** aceptado (implementado y probado en el servidor; pendiente de desplegar y del cliente Flutter)
- **Fecha:** 2026-11-09
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Relación:** [ADR-0013 — Código de sala y caducidad](./0013-codigo-de-sala-y-caducidad.md); amenazas AM-01, AM-03 y AM-11 en `docs/amenazas-priorizadas.md`
- **Aspecto:** A-01 — Sincronización de reproducción de audio

## Contexto y problema

Hasta la semana 14 cualquiera que conociera el código de una sala podía reproducirla, pausarla, subir una pista o cambiarla (AM-01). Las pruebas con un iPhone mostraron además tres carencias de producto: un receptor que se iba seguía apareciendo en la vista del emisor (el servidor nunca quitaba participantes y el emisor no recibía eventos), el emisor no podía volver a su sala, y no se podía cambiar la canción ni expulsar a alguien. Como el nombre del emisor lo ven todos en la lista de participantes, autorizar por nombre no protege nada.

## Decisión

1. **Llave de emisor.** `POST /rooms` devuelve `emitterKey` (24 bytes aleatorios, base64url) **una sola vez**; SQLite guarda solo su hash SHA-256 (`emitter_key_hash`) y se compara en tiempo constante. Se envía como `Authorization: Bearer <llave>`. La exigen `play`, `pause`, `audio`, `track`, `kick`, `events`, `DELETE /rooms/:id` y `POST /rooms/:id/emitter`. Se comprueba **antes** de leer el cuerpo, para no aceptar un MP3 de 50 MB de quien no tiene permiso. Sin llave: 401; llave ajena: 403.
2. **El cliente guarda la llave en el dispositivo** (decisión del equipo: más cómodo que un PIN). Consecuencia: quien desinstale la app o borre sus datos pierde el control de esa sala, y solo se puede volver como emisor desde ese dispositivo.
3. **Salas anteriores a las llaves** (`emitter_key_hash` nulo) siguen funcionando sin llave y el emisor vuelve por su nombre, hasta que caduquen (24 h).
4. **Salir.** `DELETE /rooms/:id/receivers/:receiverId` quita al receptor y corta su conexión. Los receptores no tienen llave, así que quien conozca el identificador de otro receptor puede sacarlo: se acepta como riesgo bajo (no puede tocar al emisor ni la reproducción) y quien sale puede volver a entrar.
5. **Expulsar.** `POST /rooms/:id/kick` (con llave) quita al receptor y **veta su nombre** en esa sala (`removed_participants`); si intenta volver, 403. El expulsado recibe `participant.left` con `reason: removed` antes de que se cierre su conexión.
6. **Eventos en vivo.** `GET /rooms/:id/events` (con llave) entrega al emisor, en NDJSON, `participant.joined|left|connected|disconnected`, `track.changed` y `room.closed`; los receptores reciben los mismos por su `stream`. `GET /rooms/:id` agrega `connected` a cada receptor. Una sala con el emisor escuchando no caduca.
7. **Cambiar la canción.** Cada `POST .../track` reemplaza la pista, deja la sala detenida en la posición 0, sube `trackVersion` y guarda `trackName` (cabecera `X-Track-Name`, codificada, hasta 100 caracteres) y avisa con `track.changed`.
8. **Cerrar la sala.** `DELETE /rooms/:id` (con llave) avisa con `room.closed`, borra pista y sala y corta las conexiones (cierra AM-11).

## Consecuencias

- **Rompe a los clientes anteriores en las acciones del emisor** (`play`, `pause`, `track`): el cliente Flutter de la semana 13 no envía la llave. Servidor y cliente deben desplegarse juntos.
- Un receptor sigue sin credencial (`join`, `stream`, `ack`, `leave` se reconocen por identificador): AM-01 queda cerrado para el emisor y abierto para los receptores.
- Perder la llave no tiene recuperación. Es deliberado: no hay cuentas.
- La lista de participantes es memoria + base: `connected` se calcula con los `stream` abiertos de este proceso, así que no es válido con varias instancias.
- Se descarta, por ahora, que los receptores suban canciones (haría falta una cola de reproducción, cuotas por persona y moderación).
- **Pendiente:** cuota de tamaño y de espacio de subida (AM-03, ahora al menos autenticada), token de receptor, y el cliente Flutter (paquete B2).
