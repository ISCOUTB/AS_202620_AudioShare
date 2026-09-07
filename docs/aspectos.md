# Aspectos

## A-01 — Sincronización de reproducción de audio

### Descripción

El sistema debe permitir que un dispositivo emisor comparta información de reproducción de audio con varios dispositivos receptores conectados a la misma red Wi-Fi, proporcionando un mecanismo de sincronización común para coordinar el inicio de la reproducción.

En el corte vertical implementado se valida el flujo de creación de una sala, incorporación de varios receptores, generación de una orden de reproducción sincronizada y distribución de paquetes de audio.

### Tipo de usuario

Emisor y receptores.

### Problema que resuelve

Permite establecer una comunicación entre un dispositivo emisor y varios dispositivos receptores para compartir eventos de reproducción y datos de audio sin utilizar cables, adaptadores o múltiples conexiones Bluetooth.

### Requisitos asociados

1. El sistema debe permitir que un dispositivo emisor transmita información de audio a uno o varios dispositivos receptores conectados a la misma red Wi-Fi.

2. El sistema debe proporcionar un mecanismo de sincronización que permita a los dispositivos receptores utilizar una misma referencia temporal para iniciar la reproducción.

### Escenarios de calidad asociados

* [EC-01 — Sincronización inicial](escenarios_calidad.md#ec-01--sincronización-inicial)
* [EC-02 — Variación moderada de latencia](escenarios_calidad.md#ec-02--variación-moderada-de-latencia)
* [EC-03 — Pausa y reanudación](escenarios_calidad.md#ec-03--pausa-y-reanudación)
* [EC-04 — Incorporación de nuevo receptor](escenarios_calidad.md#ec-04--incorporación-de-nuevo-receptor)

### Matriz de trazabilidad

| ID | Aspecto | Escenario | Objetivo / métrica | Requisito | Decisión arquitectónica | ADR | C4 | Implementación | Pruebas |
|---|---|---|---|---|---|---|---|---|---|
| A-01 | Sincronización de reproducción de audio | [EC-01 — Sincronización inicial](./escenarios_calidad.md#ec-01--sincronización-inicial) | Diferencia máxima entre receptores ≤ 100 ms | RF-01: transmitir audio a uno o varios receptores; RF-02: usar una referencia temporal común | Monolito Modular | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md) | [C4 Nivel 2 — Contenedores](./c4/C4%20Nivel%202%20-%20Contenedores.mmd) | `src/app.ts`, `src/modules/session/`, `src/modules/session/application/`, `src/modules/session/infrastructure/persistence/`, `src/modules/audio/`, `src/modules/sync/` | [`tests/a01.test.ts`](../tests/a01.test.ts) y [`tests/health.test.ts`](../tests/health.test.ts) |
| A-01 | Sincronización de reproducción de audio | [EC-02 — Variación moderada de latencia](./escenarios_calidad.md#ec-02--variación-moderada-de-latencia) | Diferencia entre receptores ≤ 200 ms | RF-02 | Monolito Modular | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md) | [C4 Nivel 2 — Contenedores](./c4/C4%20Nivel%202%20-%20Contenedores.mmd) | `src/modules/audio/`, `src/modules/sync/` | [`tests/a01.test.ts`](../tests/a01.test.ts) como recorrido base; distribución simulada y persistencia. Medición de latencia real queda pendiente |
| A-01 | Sincronización de reproducción de audio | [EC-03 — Pausa y reanudación](./escenarios_calidad.md#ec-03--pausa-y-reanudación) | Diferencia entre receptores ≤ 100 ms después de reanudar | RF-02 | Monolito Modular | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md) | [C4 Nivel 2 — Contenedores](./c4/C4%20Nivel%202%20-%20Contenedores.mmd) | `src/modules/audio/`, `src/modules/sync/` | [`tests/a01.test.ts`](../tests/a01.test.ts) como recorrido base; estado de reproducción persistido. Caso específico de pausa/reanudación queda pendiente |
| A-01 | Sincronización de reproducción de audio | [EC-04 — Incorporación de nuevo receptor](./escenarios_calidad.md#ec-04--incorporación-de-nuevo-receptor) | Nuevo receptor sincronizado ≤ 3 s | RF-01, RF-02 | Monolito Modular | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md) | [C4 Nivel 2 — Contenedores](./c4/C4%20Nivel%202%20-%20Contenedores.mmd) | `src/modules/session/`, `src/modules/sync/` | [`tests/a01.test.ts`](../tests/a01.test.ts): incorporación y recuperación desde SQLite |

### Resumen de trazabilidad

| Elemento | Referencia |
| --- | --- |
| **Aspecto** | A-01 — Sincronización de reproducción de audio |
| **Requisitos** | RF-01, RF-02 |
| **Escenarios** | EC-01, EC-02, EC-03, EC-04 |
| **ADR** | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md) |
| **C4** | [Nivel 1 — Contexto](./c4/C4%20Nivel%201%20-%20Contexto.mmd), [Nivel 2 — Contenedores](./c4/C4%20Nivel%202%20-%20Contenedores.mmd) |
| **Implementación** | `src/modules/session/`, `src/modules/audio/`, `src/modules/sync/` |
| **Punto de composición** | `src/app.ts` |
| **Prueba del recorrido A-01** | [`tests/a01.test.ts`](../tests/a01.test.ts) |
| **Pruebas de arranque** | [`tests/health.test.ts`](../tests/health.test.ts) |
| **Persistencia** | `SQLiteRoomRepository` guarda y recupera salas desde `DATABASE_FILE` |

### Decisión arquitectónica relacionada

La decisión arquitectónica asociada al aspecto A-01 se encuentra
documentada en [ADR-0001 — Selección del estilo arquitectónico](./adr/0001-usar-monolito-modular.md).

El escenario que motiva principalmente esta decisión es
[EC-01 — Sincronización inicial](./escenarios_calidad.md#ec-01--sincronización-inicial).

### Implementación

El corte vertical A-01 se implementa siguiendo la arquitectura de monolito modular definida para AudioShare. La funcionalidad se divide en los módulos `Session`, `Sync` y `Audio`, cuya integración se realiza desde `app.ts`.

* **SessionApplication:** ejecuta los casos de uso de salas, participantes y estado de reproducción mediante el puerto `RoomRepository`.
* **SQLiteRoomRepository:** implementa el puerto de persistencia y mantiene las tablas `rooms` y `participants` en `data/audioshare.sqlite`.
* **SyncCoordinator:** genera el evento `sync.start` cuando el emisor inicia la reproducción. Este evento contiene un valor `startAt` que funciona como referencia temporal común.
* **AudioStreamHub:** genera los paquetes `audio.chunk`, que representan los datos de audio que serán distribuidos a los receptores.
* **app.ts:** actúa como punto de composición y conecta los módulos mediante los endpoints HTTP.

El corte vertical permite ejecutar el siguiente flujo:

1. El emisor crea una sala.
2. Se agregan dos receptores a la sala.
3. Se consulta el estado de la sala.
4. El emisor inicia la reproducción mediante `PLAY`.
5. El módulo de sincronización genera un evento `sync.start` con un `startAt`.
6. Se genera un paquete `audio.chunk`.
7. Los datos generados quedan disponibles para ser distribuidos a los receptores mediante el mecanismo de streaming.
8. La petición de `PLAY` actualiza `status`, `playback_state` y `start_at` en SQLite antes de responder.

El corte actual valida la comunicación, sincronización, distribución simulada de audio y persistencia SQLite a nivel de aplicación. El `audio.chunk` no contiene audio real: es una representación del paquete. La captura desde un dispositivo físico, su reproducción mediante altavoces y la autenticación quedan fuera de este corte vertical.

### Pruebas

La implementación se valida mediante la prueba de integración
[`tests/a01.test.ts`](../tests/a01.test.ts).

La prueba verifica:

1. La creación de una sala por parte del emisor.
2. La incorporación de dos receptores.
3. La existencia de los tres participantes dentro de la sala.
4. La ejecución de la operación `PLAY`.
5. La generación de un evento `sync.start`.
6. La generación de un valor `startAt`.
7. La generación de un paquete `audio.chunk`.
8. La secuencia y el contenido del paquete de audio.
9. La recuperación de la sala y sus receptores desde una nueva instancia de
   aplicación tras cerrar y reabrir la conexión SQLite.

La prueba usa una base SQLite temporal para evitar contaminar la base de
desarrollo y se ejecuta junto con las pruebas existentes mediante:

```bash
npm test
```

Resultado actual:

```text
Test Files  2 passed (2)
Tests       5 passed (5)
```

La integración continua ejecuta `npm run verify`, que compila TypeScript y
ejecuta este mismo recorrido junto con las pruebas de arranque en cada push
y pull request.
