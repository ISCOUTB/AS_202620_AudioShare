# 0007 — Corrección de reloj del receptor y ACK de arranque para medir EC-01

- **Estado:** propuesto (pasa a aceptado cuando el equipo lo confirme)
- **Fecha:** 2026-10-12
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Escenario de calidad relacionado:** [EC-01 — Sincronización inicial](../escenarios_calidad.md#ec-01--sincronización-inicial)
- **Complementa a:** [ADR-0005](./0005-validacion-sincronizacion-inicial.md) (no lo reemplaza ni lo modifica)

## Contexto

El ADR-0005 eligió `startAt` como referencia temporal común y descartó
explícitamente "utilizar la hora local de cada receptor" porque los relojes
pueden no estar sincronizados. La implementación posterior contradecía esa
decisión: el servidor genera `startAt = Date.now() + 500` (reloj del
servidor) y ningún receptor lo convertía a su reloj local. El cliente Flutter
solo mostraba el valor. Un receptor con el reloj adelantado 3 s habría
arrancado de inmediato; uno atrasado 2,5 s, 3 s tarde.

Además la prueba de EC-01 (`tests/sync-a01.test.ts`) calculaba constantes sin
ejercitar el sistema, y el servidor no recibía confirmación de los
receptores, por lo que no podía medir el desfase real.

## Alternativas consideradas

### A. Mantener `startAt` sin corrección (estado anterior)
- **Por qué no:** reintroduce la alternativa que el ADR-0005 ya descartó;
  con relojes desfasados el arranque difiere en segundos (desfase real
  medido: ≈ 3000 ms; ver `docs/evidencia-a01-ec01.md`).

### B. Sincronizar relojes del dispositivo (NTP del sistema operativo)
- **A favor:** corrige el problema en origen.
- **Por qué no:** una app móvil no puede ajustar el reloj del sistema ni
  depender de que el usuario lo haga; no es verificable desde el servidor.

### C. Estimar el offset de reloj en cada receptor con `GET /time`
- **A favor:** no requiere permisos; es el mismo principio de NTP
  simplificado (punto medio del viaje de ida y vuelta, muestra de menor RTT);
  la lógica es pura y se puede probar en ambos lados (TypeScript y Dart).
- **En contra:** la precisión depende de la simetría de la red Wi-Fi; con
  asimetría fuerte el error puede llegar a la mitad del RTT.
- **Se elige.**

## Decisión

1. El servidor expone `GET /time` (reloj del servidor).
2. Cada receptor toma varias muestras antes de la sesión, calcula
   `offsetMs = serverTime − (t0 + t1)/2` con la muestra de menor RTT, y espera
   `startAt − (relojLocal + offsetMs)` ms antes de arrancar
   (`delayUntilStart`, en `src/modules/sync/index.ts` y
   `lib/features/sync/domain/sync_service.dart`).
3. Al arrancar, el receptor reporta `POST /rooms/{id}/receivers/{rid}/ack`
   con su instante local y su offset. El servidor lo lleva a su reloj
   (`startedAt + offsetMs`) y calcula la diferencia entre el primer y el
   último receptor (`GET /rooms/{id}/sync`, `/metrics`).
4. La responsabilidad sigue en el contexto `Sync`: `SyncMeasurements` es el
   único dueño de los instantes de arranque; `Session` y `Audio` no los
   escriben.

## Consecuencias

- **Positivas:** EC-01 pasa a tener una medición del protocolo reproducible
  (prueba con receptores simulados de relojes +3 s, −2,5 s y +120 ms:
  desfase real de arranque ≈ 2–7 ms con corrección, ≈ 3000 ms sin ella,
  medido con un reloj de referencia único); la prueba
  falla si se rompe la corrección (ver `docs/evidencia-a01-ec01.md`).
- **Negativas / costos asumidos:** el ACK lo informa el propio receptor y el
  servidor confía en él (aceptable para medición académica, no para control
  de acceso); la medición con receptores simulados no incluye la latencia de
  la salida de audio del dispositivo; el cliente Flutter aún no llama a
  `/time` ni envía el ACK (la lógica de cálculo ya existe y está probada).
- **Riesgos y qué los dispararía:** redes Wi-Fi con latencia asimétrica
  degradan la estimación del offset → subir el número de muestras o medir de
  nuevo durante la sesión (EC-02).
- **Qué habría que revisar si cambia:** si el audio real exige precisión de
  muestra (< 10 ms), habrá que añadir compensación de latencia de salida del
  dispositivo y re-sincronización periódica.

## Trazabilidad

- Aspecto: A-01 — Sincronización de reproducción de audio (EC-01).
- Elementos C4 afectados: C4 Nivel 3 — Componentes (`SyncService` del
  cliente; módulo `Sync` del backend).
- Implementación: `src/modules/sync/index.ts`, `src/app.ts` (`/time`,
  `/rooms/{id}/receivers/{rid}/ack`, `/rooms/{id}/sync`),
  `src/shared/metrics.ts`, `lib/features/sync/domain/sync_service.dart`.
- Contratos: `docs/contracts/openapi.yaml`, `docs/contracts/asyncapi.yaml`.
- Pruebas: `tests/sync-a01.test.ts`, `tests/support/simulated-receiver.ts`,
  `tests/contract.test.ts`, `test/sync_service_test.dart`.
