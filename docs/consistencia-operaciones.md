# Operaciones y garantías de consistencia

**Proyecto:** AudioShare. **Alcance:** Flutter, backend Node/Express y SQLite.  
**Nota:** la tabla es el diseño objetivo. La sección «Verificación contra la implementación» contrasta con el código real las operaciones crear sala, PLAY y subir MP3, y dice qué garantía existe hoy y cuál no. Una garantía solo se marca como implementada cuando el código y una prueba la demuestran.

## Principios
1. SQLite es la fuente de verdad para salas, participantes y estado de reproducción persistido.
2. Las modificaciones del estado de una sala se validan y persisten en el backend antes de anunciar éxito.
3. Los eventos del stream notifican cambios, pero no sustituyen la lectura del estado persistido.
4. El MP3 es un objeto binario almacenado fuera de SQLite; su asociación con la sala requiere un protocolo de publicación y recuperación.
5. EC-01 (desfase ≤100 ms) y EC-02 (variación de latencia ≤200 ms) son objetivos de calidad, no garantías demostradas por la consistencia de la base de datos.

## Tabla operación → garantía

| Operación | Dato autoritativo | Garantía requerida | Mecanismo propuesto | Fallo/recuperación | Verificación |
|---|---|---|---|---|---|
| Crear sala | SQLite | Atomicidad: completa o inexistente | Insertar en transacción; devolver ID/código tras commit | No anunciar éxito si falla | Fallo de persistencia no deja sala parcial |
| Unirse a sala | Sala y participante en SQLite | Integridad y control de duplicados | Validar sala e insertar con restricción única apropiada | Reintento devuelve/reutiliza sesión según política | Repetir solicitud y probar sala inexistente |
| Consultar participantes | SQLite | Leer último estado confirmado | Consultar backend; no usar caché como autoridad | Error explícito si falla la lectura | Incorporación seguida de consulta |
| Play | Estado de reproducción en SQLite | Estado, posición y startAt coherentes | Guardar la transición atómicamente; publicar tras commit | Si falla DB, no publicar éxito | Evento coincide con lectura posterior |
| Pause | Estado de reproducción en SQLite | Transición ordenada y posición coherente | Calcular posición en backend y guardar posición/estado juntos | Reintento devuelve estado vigente | Pausa, lectura y reintento |
| Resume | Estado de reproducción en SQLite | Nueva referencia temporal coherente con posición | Guardar posición y nuevo startAt en una transición | No emitir evento antes del commit | Prueba pausa/reanudación |
| Consultar snapshot | SQLite | Snapshot de estado confirmado | Endpoint consulta estado actual; versión creciente si se implementa | Tras reconexión, obtener snapshot nuevo | Reconexión recupera estado correcto |
| Distribuir eventos | Estado confirmado en SQLite | Orden por sala y detección de pérdidas | Publicar tras commit; incluir versión por sala si se implementa | Al reconectar, leer snapshot; ignorar duplicados por versión | Orden, duplicados y reconexión |
| Subir MP3 | Archivo persistente + metadatos | No servir carga parcial | Escribir temporal, validar, renombrar y luego confirmar metadatos | Limpiar/reconciliar archivos huérfanos | Carga truncada y fallo de DB |
| Descargar MP3/Range | Archivo asociado a la sala | Integridad de bytes y aislamiento | Validar asociación y servir el objeto correcto | 404 si no hay pista; nunca servir otra sala | Comparar bytes y probar Range |
| Desconectar participante | Participante/presencia | Política explícita de presencia frente a pertenencia | Definir si desconectar elimina presencia o registro | Reconectar leyendo estado del servidor | Desconexión/reconexión |

## Alcance de las garantías
- **Transacción SQLite:** atomicidad para operaciones incluidas en una misma transacción.
- **Orden por sala:** requiere serialización o control de concurrencia explícito; no se presupone por usar SQLite.
- **Eventos:** consistencia eventual con el estado persistido; pueden perderse durante una desconexión.
- **Archivo + SQLite:** no comparten una transacción atómica. Se necesita publicación ordenada y reconciliación.
- **Audio:** consistencia del estado no demuestra desfase físico ≤100 ms; se requiere medición con equipos reales.

## Criterios de aceptación
1. Cada comando de reproducción exitoso coincide con el estado leído inmediatamente después.
2. Un error de persistencia no produce evento de éxito.
3. Un cliente que pierde el stream recupera el estado mediante snapshot.
4. Una pista incompleta nunca queda disponible.
5. Las pruebas separan garantías verificadas de objetivos pendientes.

## Verificación contra la implementación (S12)

Contraste hecho el 2026-10-25 sobre `src/app.ts`, `sqlite-room-repository.ts` y `src/modules/audio/index.ts`. Las referencias a línea corresponden a ese estado.

### Crear sala — `POST /rooms` (`src/app.ts:138`, `SQLiteRoomRepository.createRoom`, `sqlite-room-repository.ts:55-86`)

| Aspecto | Hallazgo |
|---|---|
| Garantía declarada | Atomicidad: la sala y su emisor existen juntos o no existen |
| Implementada | Sí. `INSERT INTO rooms` e `insertParticipant` van dentro de una misma `database.transaction`; el resultado se lee con `getRoom` después del commit |
| No implementada | Idempotencia: no hay clave de petición; reintentar tras un timeout crea otra sala (el id es un UUID aleatorio) |
| Fallo entre pasos | Si la transacción lanza, SQLite la revierte y no queda sala parcial. No hay manejador específico: el cliente recibe el 500 genérico de Express (ver FM-05) |
| Prueba | `tests/a01.test.ts` verifica que la sala y sus receptores persisten al reabrir la base. **No existe prueba de fallo parcial**: pendiente |

### PLAY — `POST /rooms/:roomId/play` (`src/app.ts:254-310`)

Secuencia real del manejador:

1. Lee la sala en SQLite y calcula `resumeFrom` (conserva la posición si ya suena).
2. `sync.start(resumeFrom)` cambia el estado **en memoria** del `SyncCoordinator` y fija `startAt`.
3. `sessions.startPlayback` ejecuta un único `UPDATE rooms SET status, playback_state, start_at` (`updatePlaybackState`): estado, posición y `startAt` se escriben en una sola sentencia.
4. Publica `sync.start` y `audio.chunk` en las conexiones abiertas de la sala.
5. Responde 200.

| Aspecto | Hallazgo |
|---|---|
| Garantía declarada | Estado, posición y `startAt` coherentes; no anunciar éxito ni publicar antes de persistir |
| Implementada | **Persistir antes de publicar y antes de responder 200** (pasos 3 → 4 → 5). Estado, posición y `startAt` son coherentes porque van en un solo `UPDATE`. El manejador no tiene `await`: dentro de un proceso, dos PLAY de una misma sala no se intercalan |
| No implementada | (a) El paso 2 ocurre antes del 3: si el `UPDATE` falla, el coordinador en memoria queda en `playing` y diverge de SQLite (FM-05). (b) Si el proceso cae entre 3 y 4, SQLite dice `playing` pero ningún receptor recibió el evento y no hay replay. (c) Si un `send` falla a mitad del bucle del paso 4, el estado ya está persistido, algunos receptores recibieron el evento y el emisor ve un 500. (d) PLAY no es idempotente: repetirlo calcula otro `startAt` y emite otro evento (FM-04). (e) El orden por sala solo vale dentro de un proceso; no hay garantía con varias instancias |
| Recuperación | El cliente lee `GET /rooms/:roomId` (`status`, `playbackState`, `startAt`, `participants`), que devuelve el estado confirmado |
| Pruebas | `tests/resume-position.test.ts` (posición al pausar y reanudar) y `tests/consistency-cache.test.ts` (la respuesta de PLAY coincide con la lectura posterior; una sala inexistente responde 404 sin crear estado). **Falta** una prueba de fallo entre persistir y publicar |

### Subir MP3 — `POST /rooms/:roomId/track` (`src/app.ts:391`, `AudioTrackStore.save`)

| Aspecto | Hallazgo |
|---|---|
| Garantía declarada | No servir una carga parcial |
| Implementada (S12) | `AudioTrackStore.save` escribe un archivo temporal `{roomId}.mp3.{uuid}.tmp` en el mismo directorio y lo renombra sobre el definitivo; si falla, borra el temporal y conserva la pista anterior. Prueba: `tests/consistency-cache.test.ts` |
| No implementada | No hay metadatos de pista en SQLite: la asociación sala → pista es el nombre `tracks/{roomId}.mp3`. No hay versiones, ni hash, ni reconciliación de temporales huérfanos tras una caída. En Windows el renombrado puede fallar si el archivo está abierto; en ese caso la subida responde 500 y la pista anterior se conserva |

## Garantía del flujo de eventos

**Garantía elegida: como máximo una vez por conexión abierta (*at-most-once*), sin reentrega ni replay, con recuperación del estado por consulta.**

- **Entrega.** El servidor escribe `sync.start`, `sync.pause` y `audio.chunk` en la conexión NDJSON de cada receptor conectado en ese instante. No espera confirmación de transporte ni reintenta.
- **Pérdida.** Un receptor desconectado cuando ocurre PLAY o PAUSE pierde el evento. No hay cola ni replay, y al abrir el stream no se envía el estado actual (FM-09).
- **Duplicados y orden.** `sync.start` y `sync.pause` no llevan identificador ni versión, así que el receptor no puede detectar pérdidas ni duplicados. `audio.chunk` lleva `sequence`, pero es un contador global del proceso (`AudioStreamHub`), no por sala, y se reinicia al reiniciar el servidor.
- **Deduplicación.** El servidor no deduplica: un PLAY repetido emite un `sync.start` nuevo con otro `startAt` (FM-04). **Supuesto que debe cumplir el receptor:** tratar un `sync.start` más reciente como sustituto del anterior. Este supuesto no está verificado en el cliente Flutter.
- **Recuperación.** Tras reconectar, el cliente consulta `GET /rooms/:roomId` y reconstruye el estado. Pendiente de diseño: un evento `sync.snapshot` al abrir el stream y una versión creciente por sala.
- **ACK de arranque.** `POST .../ack` es una medición del desfase (EC-01), no una confirmación de entrega.
- **Por qué es aceptable.** Un `sync.start` pierde valor cuando pasa `startAt`; reentregarlo tarde no ayuda a la sincronización. Importa más que el estado consultable sea correcto que reentregar eventos.

Este texto complementa a `docs/contracts/asyncapi.yaml`, que ahora declara la misma garantía en su descripción.

## Qué sigue pendiente

Prueba de fallo entre persistir y publicar en PLAY; reordenar PLAY como «calcular → persistir → actualizar coordinador → publicar» (FM-05); PLAY idempotente por estado (FM-04); `sync.snapshot` al abrir el stream (FM-09); versionado de pistas y reconciliación de temporales (ADR-0011).
