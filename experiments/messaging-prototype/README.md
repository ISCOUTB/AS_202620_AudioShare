# Prototipo de mensajería asíncrona de AudioShare

## Objetivo

Evaluar el uso de mensajes para solicitar la sincronización de un receptor que se incorpora a una sala.

Este prototipo es independiente del flujo de producción y no modifica los módulos Session, Audio o Sync.

## Contrato

El mensaje utilizado es `receiver.sync.requested`, versión 1.

Contiene los siguientes campos:

- `schemaVersion`: versión del contrato.
- `messageId`: identificador único del mensaje.
- `type`: tipo de evento.
- `occurredAt`: fecha de creación del mensaje.
- `correlationId`: identificador para relacionar registros.
- `payload.roomId`: identificador de la sala.
- `payload.receiverId`: identificador del receptor.
- `payload.targetPositionMs`: posición objetivo de reproducción.

Los mensajes con versiones desconocidas son rechazados.

Los cambios incompatibles requieren una nueva versión del contrato.

## Entrega y reintentos

El simulador procesa los mensajes mientras el proceso permanece activo.

Se permiten tres intentos por defecto.

El backoff es exponencial:

`baseBackoffMs * 2^(intento - 1)`

Los mensajes que agotan sus intentos se guardan en `deadLetters`.

## Idempotencia

El prototipo identifica los mensajes procesados mediante `messageId`.

Si llega nuevamente un mensaje cuyo procesamiento terminó correctamente, se ignora.

Esta deduplicación solo existe en memoria.

## Observabilidad

Los registros incluyen:

- `messageId`
- `correlationId`
- evento
- número de intento
- tiempo de espera cuando corresponde
- tiempo transcurrido cuando corresponde

## Pruebas

Desde la raíz del repositorio:

`npm test -- tests/messaging-prototype.test.ts`

Después, ejecutar la verificación completa:

`npm run verify`

## Límites

El prototipo no utiliza RabbitMQ ni otro broker.

La cola y la deduplicación se mantienen en memoria y se pierden al reiniciar el proceso.

El procesamiento es secuencial y simulado.

No está conectado a la API de AudioShare y no demuestra sincronización física del audio.

No debe considerarse una implementación productiva de mensajería durable.
