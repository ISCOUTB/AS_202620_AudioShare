# Trazabilidad arquitectónica

## A-01 — Sincronización de reproducción de audio

### Descripción

AudioShare es una aplicación desarrollada en Flutter que permite representar el flujo de creación de una sala y la coordinación de reproducción de audio entre un dispositivo emisor y varios dispositivos receptores conectados a la misma red Wi-Fi.

El corte vertical A-01 conserva el objetivo funcional definido inicialmente para AudioShare: crear una sala, incorporar receptores, iniciar una reproducción mediante una referencia temporal común y coordinar la distribución de información de audio.

La migración a Flutter modifica principalmente la implementación del cliente y la forma en que la interfaz interactúa con los componentes de la aplicación. El alcance funcional del corte A-01 se mantiene.

### Tipo de usuario

Emisor y receptores.

### Problema que resuelve

Permite establecer una comunicación entre un dispositivo emisor y varios dispositivos receptores para compartir información de reproducción de audio y coordinar su reproducción sin utilizar cables, adaptadores o múltiples conexiones Bluetooth.

### Requisitos asociados

1. El sistema debe permitir que un dispositivo emisor transmita información de audio a uno o varios dispositivos receptores conectados a la misma red Wi-Fi.

2. El sistema debe proporcionar un mecanismo de sincronización que permita a los dispositivos receptores utilizar una misma referencia temporal para iniciar la reproducción.

### Escenarios de calidad asociados

* [EC-01 — Sincronización inicial](./escenarios_calidad.md#ec-01--sincronización-inicial)
* [EC-02 — Variación moderada de latencia](./escenarios_calidad.md#ec-02--variación-moderada-de-latencia)
* [EC-03 — Pausa y reanudación](./escenarios_calidad.md#ec-03--pausa-y-reanudación)
* [EC-04 — Incorporación de nuevo receptor](./escenarios_calidad.md#ec-04--incorporación-de-nuevo-receptor)

---

## Matriz de trazabilidad

| ID   | Aspecto                                 | Escenario                                                                                                 | Objetivo / métrica                                       | Requisito                                                                                        | Decisión arquitectónica              | ADR                                                                                                                                                  | C4                                                               | Implementación                                                                                    | Pruebas                                                                             |
| ---- | --------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| A-01 | Sincronización de reproducción de audio | [EC-01 — Sincronización inicial](./escenarios_calidad.md#ec-01--sincronización-inicial)                   | Diferencia máxima entre receptores ≤ 100 ms              | RF-01: transmitir audio a uno o varios receptores; RF-02: utilizar una referencia temporal común | Monolito Modular con cliente Flutter | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md), [ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md) | [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd) | `lib/` — `Home`, `SessionViewModel`, `RoomRepository`, `ApiClient`, `SyncService`, `AudioService` | `test/models_test.dart`, `test/view_model_test.dart`, `test/widget_test.dart`       |
| A-01 | Sincronización de reproducción de audio | [EC-02 — Variación moderada de latencia](./escenarios_calidad.md#ec-02--variación-moderada-de-latencia)   | Diferencia entre receptores ≤ 200 ms                     | RF-02                                                                                            | Monolito Modular con cliente Flutter | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md), [ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md) | [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd) | `lib/` — `SessionViewModel`, `SyncService`, `AudioService`                                        | Pruebas de modelo y ViewModel; medición física de latencia queda pendiente          |
| A-01 | Sincronización de reproducción de audio | [EC-03 — Pausa y reanudación](./escenarios_calidad.md#ec-03--pausa-y-reanudación)                         | Diferencia entre receptores ≤ 100 ms después de reanudar | RF-02                                                                                            | Monolito Modular con cliente Flutter | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md), [ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md) | [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd) | `lib/` — `SessionViewModel`, `SyncService`, `AudioService`                                        | Pruebas de ViewModel; caso específico de medición de sincronización queda pendiente |
| A-01 | Sincronización de reproducción de audio | [EC-04 — Incorporación de nuevo receptor](./escenarios_calidad.md#ec-04--incorporación-de-nuevo-receptor) | Nuevo receptor sincronizado ≤ 3 s                        | RF-01, RF-02                                                                                     | Monolito Modular con cliente Flutter | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md), [ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md) | [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd) | `lib/` — `SessionViewModel`, `RoomRepository`, `SyncService`                                      | Pruebas de ViewModel y modelos; caso específico queda pendiente                     |

---

## Resumen de trazabilidad

| Elemento                              | Referencia                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------------- |
| **Aspecto**                           | A-01 — Sincronización de reproducción de audio                                |
| **Requisitos**                        | RF-01, RF-02                                                                  |
| **Escenarios**                        | EC-01, EC-02, EC-03, EC-04                                                    |
| **ADR principal**                     | [ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md)       |
| **ADR de migración tecnológica**      | [ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md)   |
| **C4**                                | [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd)              |
| **Implementación**                    | `lib/`                                                                        |
| **Interfaz principal**                | `Home`                                                                        |
| **Estado y casos de uso del cliente** | `SessionViewModel`                                                            |
| **Acceso a salas**                    | `RoomRepository`                                                              |
| **Comunicación con servicios**        | `ApiClient`                                                                   |
| **Sincronización**                    | `SyncService`                                                                 |
| **Audio**                             | `AudioService`                                                                |
| **Pruebas**                           | `test/models_test.dart`, `test/view_model_test.dart`, `test/widget_test.dart` |

---

## Decisiones arquitectónicas relacionadas

La decisión arquitectónica general del proyecto se encuentra documentada en:

[ADR-0001 — Usar monolito modular](./adr/0001-usar-monolito-modular.md).

Con la migración de la aplicación hacia Flutter se incorporó una decisión adicional:

[ADR-0002 — Cliente Flutter](./adr/0002-cliente-flutter-backend-modular.md).

El cambio tecnológico mantiene el objetivo funcional de AudioShare y reorganiza la implementación del cliente alrededor de componentes Flutter.

La arquitectura documentada actualmente considera componentes del cliente como:

* `Home`: interfaz principal de la aplicación.
* `SessionViewModel`: coordina el estado y las operaciones de una sesión.
* `RoomRepository`: abstrae las operaciones relacionadas con las salas.
* `ApiClient`: encapsula la comunicación con los servicios de la aplicación.
* `SyncService`: concentra la lógica relacionada con la sincronización.
* `AudioService`: concentra las operaciones relacionadas con el audio.

La relación entre estos componentes se encuentra representada en el [C4 Nivel 3 — Componentes](./c4/Componentes%20-%20Nivel%203.mmd).

---

## Implementación

El corte vertical A-01 se conserva como referencia funcional del proyecto, pero su implementación del lado del cliente fue migrada a Flutter.

La aplicación Flutter organiza el flujo mediante los siguientes componentes:

### Home

Representa la interfaz principal desde la cual el usuario interactúa con las funcionalidades de AudioShare.

### SessionViewModel

Coordina el estado de la sesión y sirve como punto de conexión entre la interfaz y los servicios/repositorios utilizados por la aplicación.

### RoomRepository

Abstrae las operaciones relacionadas con las salas y permite que la lógica de la sesión no dependa directamente de los detalles de comunicación.

### ApiClient

Encapsula la comunicación con los servicios de AudioShare. Su responsabilidad es separar la lógica de comunicación de la lógica de presentación y estado de la aplicación.

### SyncService

Gestiona la lógica relacionada con la sincronización de reproducción y la referencia temporal utilizada para coordinar a los dispositivos.

### AudioService

Centraliza las operaciones relacionadas con el audio dentro de la aplicación.

La migración a Flutter no implica agregar funcionalidades nuevas al corte A-01. El objetivo es conservar el alcance funcional existente utilizando una aplicación multiplataforma como cliente.

---

## Flujo del corte vertical A-01

El flujo funcional que se mantiene después de la migración es:

1. El emisor inicia la aplicación AudioShare.
2. El emisor crea una sala.
3. Los receptores se incorporan a la sala.
4. La sesión mantiene el estado de los participantes.
5. El emisor inicia la reproducción.
6. `SessionViewModel` coordina la operación de reproducción.
7. `SyncService` gestiona la referencia temporal utilizada para la sincronización.
8. `AudioService` gestiona la información relacionada con el audio.
9. Los receptores utilizan la información de sincronización para coordinar la reproducción.

La implementación actual debe considerarse como un corte vertical de validación de la arquitectura y del flujo funcional. La captura de audio físico, la reproducción física sincronizada entre múltiples dispositivos y la medición experimental de las diferencias temporales entre dispositivos permanecen como aspectos que deben validarse mediante pruebas específicas.

---

## Pruebas

La migración a Flutter incorpora pruebas dentro del directorio `test/`.

Las pruebas actuales se organizan en:

* `test/models_test.dart`: pruebas relacionadas con los modelos de la aplicación.
* `test/view_model_test.dart`: pruebas relacionadas con el estado y comportamiento del `SessionViewModel`.
* `test/widget_test.dart`: pruebas relacionadas con los componentes de interfaz Flutter.

Estas pruebas sustituyen la función de las pruebas específicas del cliente que anteriormente estaban concentradas en `tests/a01.test.ts`.

La trazabilidad de A-01 debe considerar las pruebas Flutter como evidencia del comportamiento del cliente.

Las mediciones de los escenarios de calidad EC-01, EC-02, EC-03 y EC-04 no deben presentarse como verificadas únicamente por las pruebas unitarias o de interfaz. Para afirmar que se cumplen las métricas de sincronización se requieren pruebas de integración o pruebas sobre dispositivos reales.

---

## Alcance actual y pendientes

El corte vertical A-01 permite mantener la trazabilidad de la funcionalidad principal de AudioShare después de la migración tecnológica.

Actualmente se mantiene como alcance:

* Creación y manejo de salas.
* Incorporación de receptores.
* Gestión del estado de sesión.
* Coordinación de reproducción.
* Gestión de la sincronización.
* Integración del servicio de audio.
* Interfaz de usuario implementada en Flutter.

Quedan como validaciones pendientes:

* Medición experimental de la diferencia temporal entre receptores.
* Validación de EC-01 con dispositivos reales.
* Validación de EC-02 bajo variación de latencia.
* Validación específica de pausa y reanudación para EC-03.
* Medición del tiempo de incorporación y sincronización de un nuevo receptor para EC-04.
* Validación de captura y reproducción de audio físico en varios dispositivos.

Por lo tanto, las métricas de los escenarios de calidad se mantienen como objetivos arquitectónicos y no deben interpretarse como resultados experimentales mientras no exista una prueba que las mida directamente.

---

## Relación con la arquitectura

La trazabilidad de A-01 conecta:

**Requisitos → Escenarios de calidad → Decisiones arquitectónicas → Componentes Flutter → Pruebas**

De esta manera, la migración desde la implementación anterior hacia Flutter no elimina la trazabilidad del proyecto, sino que actualiza la evidencia de implementación para que corresponda con la estructura actual de la aplicación.
