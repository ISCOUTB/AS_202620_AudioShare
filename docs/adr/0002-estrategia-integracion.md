# 0002 — Estrategia de integración: contrato y acoplamiento temporal

- **Estado:** aceptado
- **Fecha:** 2026-09-18
- **Decide:** equipo AudioShare (AS_202620_AudioShare).
- **Escenarios de calidad relacionados:** [EC-01 — Sincronización inicial](../escenarios_calidad.md#ec-01--sincronización-inicial), [EC-03 — Pausa y reanudación](../escenarios_calidad.md#ec-03--pausa-y-reanudación), [EC-04 — Incorporación de nuevo receptor](../escenarios_calidad.md#ec-04--incorporación-de-nuevo-receptor)

## Contexto

AudioShare tiene dos tipos de comunicación entre el cliente y el servidor
que no se comportan igual ante un fallo:

1. **Gestión de sala**: crear sala, unirse como receptor, consultar estado.
   El cliente hace una acción y necesita saber de inmediato si tuvo éxito
   (por ejemplo, si la sala no existe, el usuario debe enterarse en ese
   momento, no después).
2. **Distribución de eventos de reproducción**: `sync.start`, `sync.pause`
   y `audio.chunk`. El emisor dispara `play`/`pause` una sola vez y ese
   evento debe llegar a N receptores que pueden estar conectados,
   desconectados o uniéndose en ese instante. El emisor no puede quedar
   bloqueado esperando que cada receptor confirme la recepción.

Hasta ahora esto no estaba escrito como contrato: los campos que expone
cada endpoint y la forma de cada evento (`type`, `startAt`, `positionMs`,
`sequence`) solo existían implícitos en el código de
[`src/app.ts`](../../src/app.ts).

## Alternativas consideradas

### A. Todo síncrono (REST puro, incluyendo la distribución de eventos)
El receptor haría *polling* a `GET /rooms/:roomId` para detectar cambios de
estado, sin canal de push.
- **A favor:** un solo estilo de integración, contrato más simple.
- **En contra:** acopla la latencia de los receptores al intervalo de
  polling; para cumplir EC-01 (sincronización ≤100 ms) el polling tendría
  que ser tan agresivo que equivaldría a saturar el servidor.
- **Por qué no se eligió:** el modo de fallo que le interesa a AudioShare
  no es "¿la sala existe?", es "¿todos los receptores arrancan al mismo
  instante?", y eso no se resuelve con acoplamiento temporal alto.

### B. Todo asíncrono (incluida la gestión de sala vía eventos)
Crear sala y unirse como receptor también se modelarían como mensajes
publicados a una cola, con el resultado llegando por un canal separado.
- **A favor:** un único paradigma de integración en todo el sistema.
- **En contra:** para crear una sala, el usuario necesita el `roomId` de
  inmediato para poder compartirlo o unirse; introducir una cola ahí solo
  añade complejidad y un modo de fallo (¿qué hace la UI mientras espera la
  confirmación?) sin ningún beneficio.
- **Por qué no se eligió:** el problema de acoplamiento temporal solo
  existe del lado de la distribución de eventos, no en la gestión de sala.

### C. Híbrido: REST síncrono para gestión de sala, canal de eventos asíncrono para reproducción
REST request/response para `/rooms`, `/rooms/:roomId`,
`/rooms/:roomId/receivers`; canal push (hoy NDJSON, migrará a WebSocket
para el cliente Flutter) para `sync.start`, `sync.pause` y `audio.chunk`.
- **A favor:** cada operación usa el modo de acoplamiento que corresponde a
  su propio modo de fallo: la gestión de sala necesita respuesta inmediata,
  la distribución de eventos necesita desacoplar al emisor de la
  disponibilidad de cada receptor individual.
- **En contra:** dos contratos distintos que mantener (OpenAPI y AsyncAPI),
  y hay que diseñar explícitamente qué le pasa a un receptor que se conecta
  tarde (no recibe eventos pasados; debe reconstruir el estado con
  `GET /rooms/:roomId` al conectarse — esto es lo que cubre EC-04).
- **Por qué se eligió:** es el reflejo directo del código que ya existe en
  `src/app.ts` (endpoints REST + endpoint de stream) y del comportamiento
  que necesitan los escenarios de calidad.

## Decisión

Se adopta una estrategia **híbrida**: contrato **OpenAPI 3.1**
([`docs/contracts/openapi.yaml`](../contracts/openapi.yaml)) para las
operaciones síncronas de gestión de sala, y contrato **AsyncAPI 3.0**
([`docs/contracts/asyncapi.yaml`](../contracts/asyncapi.yaml)) para el
canal de eventos de reproducción. Ambos contratos son la fuente única de
verdad: se validan contra la implementación real mediante una prueba de
contrato ([`tests/contract.test.ts`](../../tests/contract.test.ts)) que
falla si un endpoint deja de cumplir el esquema publicado.

## Consecuencias

- **Positivas:** cada integración queda documentada según su propio modo de
  fallo real, no según una convención uniforme forzada. Un cambio
  incompatible (quitar un campo, cambiar un tipo) rompe el pipeline en
  lugar de descubrirse en producción.
- **Negativas / costos asumidos:** mantener dos formatos de contrato en
  paralelo; cualquier cambio en `src/app.ts` que toque la forma de una
  respuesta obliga a actualizar el YAML correspondiente en el mismo commit.
- **Riesgos y qué los dispararía:** si el contrato y el código se
  desincronizan porque alguien edita `app.ts` sin tocar el YAML, la prueba
  de contrato deja de ser confiable como fuente de verdad. Esto se mitiga
  con la prueba de contrato en el pipeline (ver `.github/workflows/ci.yml`).
- **Qué habría que revisar si cambia:** si el canal de eventos migra de
  NDJSON a WebSocket (previsto para el cliente Flutter), el AsyncAPI debe
  actualizar su `channels.roomStream.address` y el `bindings` del
  transporte, pero los mensajes (`sync.start`, `sync.pause`,
  `audio.chunk`) no cambian de forma — es exactamente lo que este contrato
  debe proteger.

## Trazabilidad

- Requisito / aspecto: contrato de API explícito y verificable, base para
  el cliente Flutter y para detectar cambios incompatibles antes del
  merge.
- Elementos C4 afectados: [C4 Nivel 2 — Contenedores](../c4/C4%20Nivel%202%20-%20Contenedores.mmd)
  (sin cambios de estructura; formaliza las dos formas de comunicación que
  ya cruzan el límite del contenedor de aplicación).
- Implementación: [`src/app.ts`](../../src/app.ts) (endpoints REST y
  endpoint de stream).
- Contratos: [`docs/contracts/openapi.yaml`](../contracts/openapi.yaml),
  [`docs/contracts/asyncapi.yaml`](../contracts/asyncapi.yaml).
- Pruebas que lo cubren: [`tests/contract.test.ts`](../../tests/contract.test.ts).
