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
* ### ADR relacionado

[ADR-0001 — Usar monolito modular](adr/0001-usar-monolito-modular.md)

### Implementación

El corte vertical A-01 se implementa siguiendo la arquitectura de monolito modular definida para AudioShare. La funcionalidad se divide en los módulos `Session`, `Sync` y `Audio`, cuya integración se realiza desde `app.ts`.

* **SessionManager:** gestiona las salas y sus participantes, diferenciando entre el dispositivo emisor y los dispositivos receptores.
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

El corte actual valida la comunicación, sincronización y distribución de datos de audio a nivel de aplicación. La captura de audio desde un dispositivo físico y su reproducción mediante los altavoces quedan fuera de este corte vertical.

### Pruebas

La implementación se valida mediante la prueba de integración `tests/a01.test.ts`.

La prueba verifica:

1. La creación de una sala por parte del emisor.
2. La incorporación de dos receptores.
3. La existencia de los tres participantes dentro de la sala.
4. La ejecución de la operación `PLAY`.
5. La generación de un evento `sync.start`.
6. La generación de un valor `startAt`.
7. La generación de un paquete `audio.chunk`.
8. La secuencia y el contenido del paquete de audio.

La prueba se ejecuta junto con las pruebas existentes mediante:

```bash
npm test
```

Resultado actual:

```text
Test Files  2 passed (2)
Tests       3 passed (3)
```
