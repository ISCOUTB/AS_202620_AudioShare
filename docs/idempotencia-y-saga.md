# Diseño de idempotencia y análisis de saga

**Estado:** diseño propuesto (2026-10-18). Solo está implementada la parte de
conexiones de stream (FM-01 y FM-02, con prueba); el resto no lo está. Donde
se describe el comportamiento actual, se indica expresamente «hoy». Responde a
los modos de fallo de [`modos-de-fallo.md`](./modos-de-fallo.md) y es
la base de [ADR-0009](./adr/0009-no-extraer-modulos-como-servicios.md).

## 1. Criterio

Una operación es idempotente si repetirla con los mismos datos produce el
mismo estado final y la misma respuesta. Se busca de dos formas, en este
orden de preferencia:

1. **Por estado:** el estado actual de la sala decide si la operación hace algo.
2. **Por clave natural:** el dato ya tiene una clave que identifica el intento
   (por ejemplo `(roomId, startAt, receiverId)` en un ACK).

No se adopta una tabla genérica de claves de idempotencia (`Idempotency-Key`):
las operaciones críticas se resuelven con una de las dos formas anteriores y
la tabla añadiría esquema, caducidad y código en un contexto que no es dueño
de ese dato. Ver §7.

## 2. Operaciones

| Operación | Hoy | Diseño | Clave o criterio |
| --- | --- | --- | --- |
| `POST /rooms` | No idempotente: cada llamada crea una sala nueva. | **Sin cambio. Riesgo aceptado:** un reintento deja una sala sin receptores. | — |
| `POST /rooms/:id/receivers` | Repetir con el mismo id falla por la clave primaria y se reporta como 404 (FM-07). | Idempotente: 200 si el id ya es receptor de esa sala; 409 si es el del emisor; 404 solo si la sala no existe. Validar que `receiverId` sea texto. | Clave natural `(roomId, receiverId)`, ya garantizada por la clave primaria. |
| `GET .../stream/:receiverId` | **Corregido el 2026-10-18** (FM-01, FM-02): la conexión nueva reemplaza y cierra a la anterior, el cierre solo borra el registro propio y la entrada de la sala se crea bajo demanda. Falta enviar `sync.snapshot` al abrir (FM-09). | Una conexión viva por receptor. La nueva reemplaza y cierra a la anterior; el cierre solo borra su propio registro. Al abrir, se envía `sync.snapshot`. | Clave natural `(roomId, receiverId)`; comparar identidad del cliente. |
| `POST /rooms/:id/play` | Cada llamada reprograma `startAt` y publica (FM-04). | Idempotente por estado (§3). | Estado de la sala. |
| `POST /rooms/:id/pause` | Repetirla produce el mismo resultado, pero sin validar el estado. | Idempotente por estado (§3). | Estado de la sala. |
| `POST .../ack` | Repetir sobrescribe la medición (`Map.set`): el último gana. | **El primero gana**; repetir devuelve el ACK ya guardado. El cuerpo incluye `startAt`; si no coincide con el vigente, 409 (FM-06). | Clave natural `(roomId, startAt, receiverId)`. |
| `POST /rooms/:id/audio` | Cada llamada genera un fragmento con número de secuencia global. | **No se reintenta.** La secuencia pasa a ser por sala y el receptor descarta duplicados y desordenados por su número. | `(roomId, sequence)`. |
| `GET` (`/rooms/:id`, `/sync`, `/time`, `/health`) | Seguros por naturaleza. | Sin cambio. Son las únicas que el cliente puede reintentar sin más. | — |

Por qué el primero gana en el ACK: el ACK dice «arranqué en X». Si el
receptor reconecta y vuelve a arrancar, ese segundo arranque no es el inicial
que EC-01 mide; con «el último gana» una reconexión taparía el valor original.

Por qué el audio no se reintenta: en tiempo real un fragmento que llega tarde
es peor que uno perdido. La idempotencia aquí significa tolerar duplicados,
no reenviar.

## 3. Estado de reproducción

Solo hay tres estados (`stopped`, `playing`, `paused`; es la restricción
`CHECK` de la tabla `rooms`). Transiciones:

| Estado actual | `PLAY` | `PAUSE` |
| --- | --- | --- |
| `stopped` | → `playing`, `startAt` nuevo, se publica `sync.start`. | 409 «La sala no ha iniciado reproducción». |
| `playing` | 200 con el `startAt` vigente. **No** publica ni reprograma. | → `paused`, se publica `sync.pause` con la posición. |
| `paused` | → `playing`, reanuda desde `positionMs`, `startAt` nuevo, se publica `sync.start`. | 200, sin cambios ni publicación. |

Dependencias y advertencias:

- La reanudación desde `positionMs` requiere resolver FM-08. Hoy `PLAY` desde
  `paused` empieza de cero. Mientras FM-08 no se resuelva, el diseño de
  `paused → playing` debe documentarse como «reinicia desde cero».
- Un `PLAY` idempotente por estado es peligroso si la sala queda en
  `playing` sin que nadie reproduzca (FM-03). Por eso la reconciliación al
  arrancar (`playing → paused`) va junto con este cambio, no después.
- Si hace falta reiniciar una pista que está sonando, se necesitaría una
  operación explícita (por ejemplo `restart`); hoy no existe y no se propone
  añadirla.
- Las pruebas actuales llaman a `/play` una sola vez por sala
  (`tests/a01.test.ts`, `tests/contract.test.ts`, `tests/sync-a01.test.ts`),
  por lo que este cambio no debería romperlas. Se confirma con
  `npm run verify`.
- El contrato (`docs/contracts/openapi.yaml`) hoy declara 409 solo en `ACK` y
  `/sync`. Habría que declararlo también en `PAUSE`.

## 4. Orden de efectos en `PLAY`

Hoy, en el manejador: (1) `sync.start()` marca `playing = true` y calcula
`startAt`; (2) `startPlayback` escribe en SQLite; (3) se publica a los
streams. Si (2) falla, el coordinador queda en `playing` y la base no.

Orden propuesto: **calcular `startAt` → persistir → actualizar el coordinador
→ publicar.** Con ese orden:

- Si falla la persistencia, no hay efectos visibles y la respuesta es un
  error JSON.
- Si falla la publicación a un receptor, no se revierte nada: el estado
  persistido es la verdad y el receptor la recupera con `sync.snapshot` al
  reconectar (FM-09). Se reconcilia en vez de compensar.

## 5. Reconexión

- Un receptor se identifica por `(roomId, receiverId)`. Reconectar con el
  mismo id es el caso normal, no un error.
- Al reconectar, el receptor repite `join` (idempotente), abre el stream,
  recibe `sync.snapshot` y re-sincroniza el reloj antes de actuar sobre
  `startAt` (FM-11).
- Si el snapshot indica `playing` con un `startAt` ya pasado, el receptor
  calcula su posición con su offset de reloj y entra a mitad de la pista.

## 6. Saga: no aplica hoy

Una saga hace falta cuando una operación atraviesa varios almacenes o
servicios sin una transacción común. En el sistema actual:

- Hay un solo proceso y un solo almacén (SQLite). `PLAY` toca Sync, Session y
  la publicación, pero dentro de una misma llamada local.
- La única operación con más de un efecto es `PLAY` (§4), y se resuelve
  ordenando los efectos y reconciliando, sin compensaciones.

**Qué cambiaría si se extrajera Sync** (la alternativa B de ADR-0009). `PLAY`
dejaría de ser local y sería una saga orquestada por Session:

| Paso | Acción | Compensación si falla el siguiente |
| --- | --- | --- |
| S1 | Sync reserva el inicio: `reservar(playId)` devuelve `startAt`. | `cancelar(playId)` |
| S2 | Session persiste el estado con `playId` y `startAt`. | — |
| S3 | Se publica `sync.start` (mejor con un *outbox*: el evento se guarda junto al estado y un proceso aparte lo publica, para no perderlo si el servicio cae entre S2 y S3). | — |

Cada paso tendría que ser idempotente por `playId`, con tiempos de espera,
reintentos y una forma de detectar sagas colgadas. Además `/time` tendría que
servirse desde el mismo reloj que calcula `startAt`. Es el costo que
ADR-0009 decide no pagar.

## 7. Lo que no se hace

- **Tabla genérica de `Idempotency-Key`.** Solo `POST /rooms` carecería de
  protección y su fallo es una sala vacía. No justifica una tabla.
- **Reintentos del lado del servidor.** Los reintentos los decide el cliente y
  solo sobre operaciones del §2 marcadas como seguras.
- **Entrega «al menos una vez» para el audio.** Ver §2.
