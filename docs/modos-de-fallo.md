# Modos de fallo y mitigaciones

Elaborado el 2026-10-18 sobre el repositorio con `startedAt` ya incorporado
en `/health`. El código se cita por archivo y nombre de manejador, que son
referencias estables; los números de línea se omiten a propósito porque se
desplazan con cada cambio.

## Método y alcance

- Se recorrieron los flujos reales: crear sala, unir receptor, stream NDJSON,
  `PLAY`, `PAUSE`, `ACK`, `/sync`, `/audio`, el cliente Flutter (`ApiClient`,
  `SessionViewModel`) y el despliegue (ADR-0008).
- **Evidencia.** `R` = reproducido con una prueba ejecutada
  (`tests/failure-modes.test.ts`; resultado en la sección «Resultado de las
  pruebas»). `L` = lectura del código a esa fecha: **no se ejecutó una prueba
  que reproduzca el fallo**. `D` = ya documentado en un ADR o en otro
  documento del repositorio. Solo FM-01 y FM-02 están reproducidos; el resto
  son lectura, y al final se listan las pruebas que los convertirían en
  evidencia.
- **Severidad.** Alta: rompe EC-01 o EC-04, o deja una sala inutilizable sin
  aviso al usuario. Media: degrada la medición o exige intervención manual.
  Baja: riesgo aceptable en el alcance actual.
- **Existe hoy** dice qué mitigación se encontró en el código. «No» significa
  que no se encontró ninguna.
- Fuera de alcance: el audio real (NC-01, NC-02) no existe aún. Sus modos de
  fallo se listan al final como pendientes de evaluar.

## Tabla

| ID | Modo de fallo y ubicación | Efecto | Sev. | Existe hoy | Mitigación propuesta | Ev. |
| --- | --- | --- | --- | --- | --- | --- |
| FM-01 | **La reconexión borra el registro nuevo.** `GET /rooms/:roomId/stream/:receiverId`: registra `roomStreams.set(receiverId, client)` y, al cerrarse la conexión, hace `roomStreams.delete(receiverId)` sin comprobar de quién era el registro. | Un receptor que reconecta con el mismo `receiverId` mientras el servidor aún no detectó el cierre de la conexión anterior queda conectado pero fuera del mapa: deja de recibir `sync.start` y `audio.chunk`, y `connectedReceivers` baja. | Alta | Corregido el 2026-10-18 | Implementada: borrar solo si `roomStreams.get(receiverId) === client`, y al registrar una conexión nueva cerrar la anterior. | R |
| FM-02 | **Salas persistentes pero sin entrada de stream.** El mapa `streams` solo se llena en `POST /rooms`. Tras un reinicio, las salas siguen en SQLite pero `streams.get(roomId)` es `undefined`. | `GET .../stream/...` termina de inmediato con una respuesta vacía (`src/app.ts:171-174`) y `PLAY` publica a nadie respondiendo 200. Toda sala creada antes de un redespliegue conserva sus datos pero no se puede usar para transmitir, sin error visible. | Alta | Corregido el 2026-10-18 | Implementada: la entrada de stream se crea bajo demanda (`streamsFor`), con la sala ya validada contra la base (mismo patrón que `coordinatorFor`). | R |
| FM-03 | **Estado `playing` huérfano tras reinicio.** `status` y `start_at` están en SQLite; `coordinators` y `measurements` solo en memoria. | La sala figura como `playing` sin que nadie reproduzca, y `GET /rooms/:id/sync` devuelve `acks: []` aunque `startAt` exista. Combinado con un `PLAY` idempotente por estado, el `PLAY` sería un no-op sobre una sala que no suena. | Media | No | Al arrancar, reconciliar: las salas `playing` pasan a `paused` (la posición se desconoce). Documentar que las mediciones no sobreviven a un reinicio. | L |
| FM-04 | **`PLAY` repetido reinicia a todos.** `POST /rooms/:roomId/play` no mira el estado: cada llamada calcula un `startAt` nuevo y publica otro `sync.start` y otro `audio.chunk`. | Un reintento tras un timeout (el servidor sí ejecutó) o un doble toque reprograma la reproducción de todos los receptores. | Alta | Parcial: la pantalla del emisor deshabilita INICIAR si el estado es `playing` o hay una operación en curso (`room_page.dart`), solo en el cliente. | `PLAY` idempotente por estado (ver `idempotencia-y-saga.md`, §2 y §3). | L |
| FM-05 | **Fallo parcial dentro de `PLAY`.** `sync.start()` pone `playing = true` y calcula `startAt` antes de que `startPlayback` escriba en SQLite (manejador de `POST /rooms/:roomId/play`). | Si la escritura falla (disco lleno, base bloqueada), el coordinador y la base divergen. El cliente recibe un 500 que no es JSON y `ApiClient` lo reporta como «respuesta inválida». | Media | No | Orden «calcular → persistir → actualizar coordinador → publicar». Manejador de errores que responda JSON. | L |
| FM-06 | **ACK tardío atribuido a otra reproducción.** El manejador de `.../ack` usa `room.startAt` vigente; el cuerpo del ACK no dice a qué `startAt` responde. | Un ACK de la reproducción N que llega después de `PLAY` N+1 se registra en N+1 y distorsiona el desfase medido: puede dar un falso incumplimiento o un falso cumplimiento de EC-01. | Media | No | Incluir `startAt` en el cuerpo del ACK; responder 409 si no coincide con el vigente. | L |
| FM-07 | **Reintentar el `join` devuelve un 404 engañoso.** `POST .../receivers`: la clave primaria `(room_id, id)` hace fallar el segundo `INSERT` y el `catch {}` genérico responde «Sala no encontrada». | Un receptor que reintenta tras un timeout cree que la sala no existe. Tampoco hay forma de distinguir sala inexistente de receptor repetido. | Media | No | `join` idempotente: 200 si ya es receptor de esa sala, 409 si el id es el del emisor, 404 solo si la sala no existe. | L |
| FM-08 | **La pausa no conserva la posición.** `SyncCoordinator.positionMs` nunca se actualiza (`SyncCoordinator` en `src/modules/sync/index.ts`) y `startPlayback` fija `positionMs: 0`. | `PAUSE` informa siempre posición 0 y `PLAY` posterior empieza de cero: no existe reanudación (EC-03, NC-04). | Media | No | Calcular la posición al pausar como `ahora − startAt` más lo acumulado, y reanudar desde ahí. | L, D |
| FM-09 | **El receptor que llega durante la reproducción no recibe estado.** Los eventos se publican solo en el instante de `PLAY` y `PAUSE`; al abrir el stream no se envía nada. | Un receptor nuevo o reconectado no sabe `startAt` ni la posición, salvo que consulte `GET /rooms/:id` por su cuenta (EC-04, NC-05). | Media | No | Al abrir el stream, enviar un evento `sync.snapshot` con `status`, `startAt` y `positionMs`. Sirve también para reconectar. | L, D |
| FM-10 | **Conexión muerta no detectada y escritura sin control.** `client.send` hace `res.write` sin mirar su retorno ni `writableLength`; no hay latido. | Un receptor lento o con la red caída acumula datos en memoria y sigue contando en `connectedReceivers`. Un proxy intermedio podría cerrar conexiones sin tráfico (no se verificó la configuración del proxy de Dokploy). | Media | No | Latido (línea `ping`) periódico; descartar al cliente cuyo buffer supere un umbral; el cliente reconecta con espera creciente. | L |
| FM-11 | **Estimación de reloj inválida o llegada tardía de `startAt`.** `START_LEAD_MS = 500` y el error de la estimación puede llegar a RTT/2 (ADR-0007). Si el receptor se entera después de `startAt`, `delayUntilStart` devuelve 0. | El receptor arranca tarde, o con un offset malo, y el desfase supera 100 ms. | Media | Parcial: se elige la muestra de menor RTT (`estimateBestOffset`) y el ACK registra `deviationMs`. | Descartar muestras con RTT alto, tomar varias, re-sincronizar antes de cada `PLAY` y tras reconectar. Revisar `START_LEAD_MS` con RTT reales. | L, D |
| FM-12 | **Sin control de acceso ni límites.** `/play`, `/pause` y `/audio` no identifican quién llama. `AudioStreamHub` es una sola instancia para toda la app (declarada en `src/app.ts`), así que `sequence` es global entre salas. El tamaño de `payload` solo lo limita el valor por defecto de `express.json`, que no está configurado en el código. | Quien conozca el `roomId` puede iniciar, pausar o inyectar audio. Los receptores no pueden detectar pérdidas por sala con una secuencia compartida. | Media | No (NC-06 ya lo registra) | Token de emisor al crear la sala; secuencia por sala; límite de tamaño explícito. | L, D |
| FM-13 | **El cliente no tiene timeout ni reintentos.** `ApiClient.request` no define timeout y `SessionViewModel._run` deja `loading = true` hasta que termine la operación. | Una petición colgada deja los botones deshabilitados indefinidamente. | Media | No | Timeout (valor a fijar con mediciones) y error visible. Reintentar solo operaciones idempotentes (GET, `join`, ACK). | L |
| FM-14 | **Pérdida de la base por una operación del panel.** «Fresh Volumes» o eliminar la aplicación en Dokploy; el volumen no tiene respaldos. | Se pierde `data/audioshare.sqlite`. Probabilidad baja, impacto alto. | Alta | No | Respaldo programado del volumen y una prueba de restauración. | D |
| FM-15 | **Memoria sin podar.** `SyncMeasurements.starts` (una entrada por sala y `startAt`), `coordinators` y `streams` no se limpian. | Crecimiento lento con el uso. | Baja | No | Podar al pausar o cerrar la sala, o con TTL. Riesgo aceptado con la carga estimada en `docs/costos-mensuales.md` (supuesto, no medido). | L |

## Orden sugerido de mitigación

1. **Correcciones locales, sin cambio de contrato:** FM-01 y FM-02 (ya
   corregidos, ver abajo), FM-05, FM-13 y la parte de reconciliación de
   FM-03.
2. **Con cambio de contrato** (hay que declararlo en `docs/contracts/openapi.yaml`
   y en sus pruebas): FM-04 (respuestas idempotentes y 409 en `PAUSE`),
   FM-06 (`startAt` en el ACK), FM-07 (200 al repetir `join`) y FM-09 (nuevo
   evento `sync.snapshot`).
3. **Dependen de decisiones o de operación:** FM-08 (modelo de posición),
   FM-10 (parámetros del latido), FM-12 (modelo de autenticación), FM-14
   (respaldos en el panel).

## Resultado de las pruebas (2026-10-18)

Comando: `npx vitest run tests/failure-modes.test.ts` (vitest 2.1.9). Las dos
pruebas afirman el comportamiento deseado. Con `expect.soft`, que no detiene
la ejecución, se evaluaron las 4 aserciones y **fallaron las 4**:

| Modo | Aserción | Resultado | Qué muestra |
| --- | --- | --- | --- |
| FM-01 | `connectedReceivers` es 1 | Recibió 0 | Tras cerrar la conexión A y con la B aún abierta, el servidor dejó de contar al receptor: el cierre de A borró el registro de B. |
| FM-01 | B recibe `sync.start` tras `PLAY` | No lo recibió en 2 s | El receptor reconectado, con su conexión abierta, no recibió el evento de arranque. |
| FM-02 | El stream no termina de inmediato | Terminó | Tras reiniciar sobre la misma base, la sala seguía existiendo (la precondición pasó) pero el servidor cerró la respuesta del stream. |
| FM-02 | El receptor recibe `sync.start` tras `PLAY` | No lo recibió en 2 s | Una sala creada antes del reinicio no entrega el arranque a su receptor. |

Alcance: el reinicio se simuló creando una segunda aplicación sobre el mismo
archivo SQLite dentro del mismo proceso de prueba, no con un redespliegue en
Dokploy. La conexión «A» se cerró abortando la petición del cliente, que es
el caso en que el servidor detecta el cierre antes de que otra cosa lo
reemplace; el caso de una conexión muerta que el servidor tarda en detectar
(FM-10) no se probó.

### Después de la corrección (2026-10-18)

Se corrigió `src/app.ts` (borrado de la conexión solo si es la propia, cierre
de la conexión anterior al reconectar y entrada de stream bajo demanda). Con
`npm run verify`: `tsc` compiló sin errores y pasaron **24 pruebas en 5
archivos**, incluidas las dos de `tests/failure-modes.test.ts`, que antes
fallaban. Las 22 pruebas previas siguen en verde.

Lo que esto comprueba: las dos pruebas, tal como están escritas, ya no
reproducen el defecto. Lo que no comprueba: el comportamiento en el
despliegue real de Dokploy (no se repitió allí), ni FM-10 (conexión muerta
que el servidor tarda en detectar).

## Pruebas que convertirían la lectura en evidencia

| Modo | Prueba propuesta |
| --- | --- |
| FM-01 | Servidor real: abrir dos streams con el mismo `receiverId`, cerrar el primero, hacer `PLAY` y comprobar que el segundo recibe `sync.start`. |
| FM-02 | Crear una sala con una base en disco, crear otra aplicación sobre el mismo archivo (simula el reinicio), unir un receptor, abrir su stream y comprobar que se mantiene abierto y recibe `PLAY`. |
| FM-04 | Dos `PLAY` seguidos: el segundo debe devolver el mismo `startAt` y no publicar de nuevo. |
| FM-05 | Repositorio que falle al escribir: el coordinador no debe quedar en `playing` y la respuesta debe ser JSON. |
| FM-06 | `PLAY`, `PLAY` de nuevo, ACK con el `startAt` anterior: debe responder 409. |
| FM-07 | `join` repetido con el mismo id: 200 la segunda vez; con el id del emisor: 409. |
| FM-08 | `PLAY`, espera, `PAUSE`: `positionMs` mayor que 0. |
| FM-09 | Receptor que abre el stream con la sala en `playing`: su primer evento es `sync.snapshot` con `startAt`. |

Las dos primeras filas (FM-01 y FM-02) ya están escritas y ejecutadas (ver
arriba). Las demás siguen pendientes.

## Modos que aparecerán con audio real (no evaluados)

- Pérdida, duplicado o desorden de `audio.chunk`. El audio en tiempo real
  no debe reintentarse (llegar tarde es peor que perderse); se decidirá la
  política al implementar la reproducción.
- Jitter de red y deriva del reloj durante una reproducción larga.
- Latencia de salida de audio de cada dispositivo: el ACK registra cuándo la
  aplicación ordenó reproducir, no cuándo salió el sonido, y la corrección de
  reloj no la compensa. La medición de EC-01 con dispositivos físicos necesita
  una referencia externa.
