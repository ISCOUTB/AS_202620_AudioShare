# 0009 — No extraer módulos como servicios independientes: mantener el monolito modular

- **Estado:** aceptado
- **Fecha:** 2026-10-18
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Escenarios de calidad relacionados:** [EC-01 — Sincronización inicial](../escenarios_calidad.md#ec-01--sincronización-inicial), EC-02, EC-04; restricción R-01
- **Complementa a:** [ADR-0001](./0001-usar-monolito-modular.md) (no lo reemplaza) y [ADR-0008](./0008-despliegue-con-dokploy.md)
- **Documentos de apoyo:** [`modos-de-fallo.md`](../modos-de-fallo.md), [`idempotencia-y-saga.md`](../idempotencia-y-saga.md)

## Contexto

AudioShare es un monolito modular con tres módulos (Session, Sync, Audio)
que corre como un único contenedor `api` con un volumen SQLite
(ADR-0001, ADR-0008). La pregunta de esta decisión es si alguno de ellos
conviene extraerlo como servicio con su propio despliegue.

Candidatos:

- **Sync:** dueño de `startAt` y de las mediciones de desfase. Está
  parcialmente acoplado a Session: Session persiste `status`, `playback_state`
  y `start_at` (NC-10).
- **Audio:** guarda y sirve la pista MP3 por sala y distribuye el evento
  demostrativo `audio.chunk`. El tráfico HTTP crece con el tamaño de la pista
  y el número de descargas.

Hechos del sistema, verificados en el código:

- El estado de conexión vive en memoria del proceso (`streams`, `coordinators`,
  `measurements`), así que el sistema funciona con **una sola instancia** por
  construcción.
- La persistencia es un archivo SQLite en un volumen montado por un solo
  contenedor.
- `PLAY` toca Sync, Session y la publicación a los streams en una sola
  llamada local.
- Los modos de fallo de [`modos-de-fallo.md`](../modos-de-fallo.md) (FM-01 a
  FM-15) no se originan en que los módulos compartan proceso: vienen del
  manejo de conexiones, de la falta de idempotencia y del tratamiento de
  errores. Extraer un módulo no los corregiría, y alguno (FM-05, el fallo
  parcial dentro de `PLAY`) pasaría a ser un fallo de red entre servicios.

Lo que **no** se sabe:

- No hay mediciones de consumo ni de latencia del servicio (NC-08; el
  monitoreo del panel no muestra datos, ADR-0008). La carga prevista en
  `docs/costos-mensuales.md` (500 salas al mes, 3 receptores por sala) es una
  estimación, no una medida.
- La pista MP3 real se distribuye por HTTP desde la rama actual; no hay
  captura de micrófono/live ni medición de carga o latencia física, así que
  no se puede afirmar que Audio sea un cuello de botella.

## Alternativas consideradas

### A. Mantener el monolito modular (elegida)
- **A favor:** una sola unidad de despliegue; `PLAY` sigue siendo local, sin
  fallo parcial de red y sin saga; no añade piezas a operar; el esfuerzo se
  dirige a los modos de fallo que sí existen.
- **En contra:** una sola instancia; un reinicio corta todas las conexiones
  (FM-02, FM-03); los módulos comparten proceso, de modo que una excepción no
  controlada o un bloqueo del hilo afecta a todos (`better-sqlite3` es
  síncrono y la subida/entrega de pistas comparte recursos con el API).

### B. Extraer Sync como servicio
- **A favor:** aísla al dueño de `startAt` y de las mediciones; resolvería
  NC-10 de raíz con un almacén propio; permitiría desplegarlo por separado.
- **En contra:**
  - `PLAY` pasa de una llamada local a una llamada de red entre Session y
    Sync más la publicación. Esa llamada consume parte de la antelación
    `START_LEAD_MS` (500 ms) y añade el fallo parcial «Sync fijó un `startAt`
    que Session no pudo persistir», que exige una saga con compensación
    (ver `idempotencia-y-saga.md`, §6).
  - `/time` tendría que servirse desde el mismo reloj que calcula `startAt`,
    o la corrección de reloj de ADR-0007 dejaría de ser válida.
  - Los datos de Sync hoy están en la tabla `rooms`. Separarlos exige un
    almacén propio; compartir el archivo SQLite entre servicios mantendría el
    acoplamiento de esquema que NC-10 critica.
  - Más contenedores, despliegues y observabilidad para un equipo pequeño. La
    capacidad del servidor no es el obstáculo (ADR-0008 registra 11,67 GiB de
    RAM); lo es el costo de operación.

### C. Extraer Audio como servicio de medios
- **A favor:** aislaría almacenamiento y descarga de pistas si las mediciones
  demuestran que su carga afecta al API.
- **En contra:** todavía no hay medición que muestre un cuello de botella, por
  lo que extraerlo sería optimizar sin datos. Además, distribuir eventos a
  receptores seguiría requiriendo coordinarse con el registro de streams de
  `app.ts`.

### D. Separar la persistencia de Sync dentro del monolito (NC-10)
- No es una extracción como servicio y es compatible con A. Es el paso previo
  barato y reversible de B. **No se decide aquí:** queda como decisión
  aparte del equipo sobre NC-10.

## Decisión

**No se extrae ningún módulo como servicio desplegable.** Se mantiene un
único proceso con Session, Sync y Audio.

Se reconsiderará si ocurre alguno de estos disparadores, que son medibles:

1. **T1:** una medición real (NC-08) muestra que el reenvío de Audio satura
   la CPU o el ancho de banda del contenedor con la carga objetivo. El equipo
   fija el número al medir.
2. **T2:** se necesita más de una instancia. Eso exige sacar el estado de la
   memoria del proceso, y es ahí donde extraer Sync o su estado pasa a ser una
   opción real.
3. **T3:** un módulo pasa a tener un ciclo de despliegue o un responsable
   distintos.
4. **T4:** EC-01 o EC-02 se incumplen por una causa atribuible a la competencia
   de recursos entre módulos, y no a la red ni al dispositivo.

Antes de cualquier extracción deben existir: la idempotencia por operación
de `idempotencia-y-saga.md`, un contrato explícito entre módulos, y el
repositorio propio de Sync (alternativa D).

## Consecuencias

- **Positivas:** `PLAY` sigue siendo una operación local; no se necesita saga;
  no se añade infraestructura; las correcciones de `modos-de-fallo.md` se
  pueden hacer sin coordinar servicios.
- **Aceptadas:**
  - La instancia única sigue siendo un punto único de fallo y cada despliegue
    que cambia la imagen corta las conexiones abiertas (ADR-0008).
  - NC-10 sigue abierto hasta que se decida la alternativa D.
  - La decisión descansa en una carga estimada y no medida. Los disparadores
    T1 a T4 existen para corregirla cuando haya datos.
- **No se afirma:** que el monolito cumpla EC-01 o EC-02 con celulares
  reales. Eso sigue pendiente de medición (NC-03, NC-08).

## Trazabilidad

- Escenarios: EC-01, EC-02, EC-04. Restricción R-01.
- Código afectado por la decisión: orquestación de `PLAY` en `src/app.ts` y
  módulos `src/modules/session`, `src/modules/sync` y `src/modules/audio`.
- Pruebas: esta decisión es de no cambio y no tiene prueba propia. La
  evidencia de apoyo son los modos de fallo. FM-01 y FM-02 se reprodujeron y
  luego se corrigieron, con `tests/failure-modes.test.ts`; los demás son lectura de código, y sus
  pruebas están propuestas en `modos-de-fallo.md` y aún no existen.
