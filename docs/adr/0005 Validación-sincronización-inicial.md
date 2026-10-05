# ADR-0005 — Validación de la sincronización inicial mediante referencia temporal común

- **Estado:** Aceptado
- **Fecha:** 2026-10-04
- **Decisores:** Equipo AudioShare
- **Relacionado con:** ADR 0005 — Validación de la sincronización inicial mediante referencia temporal común
- **Aspecto:** A-01 — Sincronización de reproducción de audio

## Contexto

El aspecto arquitectónico A-01 establece que AudioShare debe permitir que un dispositivo emisor coordine la reproducción de audio en varios dispositivos receptores conectados a la misma red Wi-Fi.

El corte vertical existente implementa la creación de una sala, la incorporación de receptores y la generación del evento `sync.start`. Sin embargo, las pruebas existentes validaban principalmente el flujo funcional y la existencia del valor `startAt`, pero no medían directamente la diferencia temporal entre los receptores.

Por esta razón, el equipo decidió complementar el corte vertical con una prueba específica para el escenario EC-01 — Sincronización inicial.

## Decisión

El equipo decidió utilizar `startAt` como referencia temporal común para la sincronización inicial.

Cada receptor debe utilizar esta referencia para determinar el instante en que debe iniciar la reproducción.

La validación del escenario EC-01 se realizará mediante una prueba automatizada que simula diferentes tiempos de recepción del evento y calcula la diferencia entre los instantes de inicio de los receptores.

El criterio de aceptación será:

**Diferencia máxima entre receptores ≤ 100 ms.**



La responsabilidad de generar la referencia temporal permanece en el contexto de sincronización (`Sync`), mientras que `Audio` conserva la responsabilidad relacionada con los paquetes de audio.

La persistencia continúa siendo responsabilidad exclusiva del backend mediante SQLite, de acuerdo con las decisiones arquitectónicas anteriores.

## Alternativas consideradas

### 1. Sincronización independiente por receptor

Cada receptor podría comenzar a reproducir inmediatamente después de recibir el evento.

Se descartó porque el instante de recepción puede ser diferente entre dispositivos y producir una diferencia de reproducción superior al límite definido por EC-01.

### 2. Utilizar la hora local de cada receptor

Se descartó porque los relojes de los dispositivos pueden no estar perfectamente sincronizados.

### 3. Utilizar una referencia temporal común

Fue la alternativa seleccionada porque permite que los receptores utilicen el mismo `startAt` como referencia y reduce la dependencia del instante exacto en que cada receptor recibe el mensaje.

## Consecuencias positivas

* Se puede comprobar automáticamente el criterio de EC-01.
* La sincronización mantiene una responsabilidad clara dentro del módulo `Sync`.
* No se modifica la propiedad de los datos definida en la arquitectura.
* Se obtiene una métrica reproducible para la entrega.
* La prueba puede ejecutarse sin necesitar varios dispositivos físicos.

## Consecuencias negativas

* La prueba automatizada simula la recepción de los eventos y no reemplaza una medición física entre dispositivos reales.
* La sincronización de audio físico todavía requiere una etapa posterior.
* Las condiciones reales de una red Wi-Fi pueden producir resultados diferentes a los de la prueba controlada.

## Relación con decisiones anteriores

Este ADR complementa las decisiones arquitectónicas anteriores sobre el uso de un monolito modular y la transición del cliente hacia Flutter.

No modifica la responsabilidad de SQLite establecida previamente ni modifica la separación entre `Session`, `Sync` y `Audio`.

## Evidencia

* Aspecto: `docs/aspectos.md`, A-01.
* Prueba funcional existente: `tests/a01.test.ts`.
* Nueva prueba de sincronización: `tests/sync-a01.test.ts`.
* Implementación: `src/modules/sync/`.
* Cliente: `lib/features/sync/`.
* Escenario de calidad: EC-01.

## Componente generativo

El equipo decidió no incorporar un componente generativo dentro de AudioShare para este corte.

El objetivo del sistema es transmitir y sincronizar audio entre dispositivos conectados a una red Wi-Fi. La generación de contenido mediante un modelo de IA no es necesaria para cumplir este objetivo ni aporta directamente al escenario EC-01.

La Inteligencia Artificial utilizada durante el desarrollo funciona como herramienta de apoyo al equipo y no forma parte del producto ejecutado por los usuarios.

Por esta razón no se requiere un conjunto de evaluación de un modelo generativo ni una estimación de costo por operación o latencia de inferencia.

