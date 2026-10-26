# ADR-0012: Evaluación de mensajería asíncrona mediante un prototipo aislado

- **Estado:** Propuesto para revisión del equipo.
- **Fecha:** 25 de octubre de 2026.
- **Contexto:** Taller académico de mensajería, idempotencia y reintentos.
- **Relación:** [ADR-0001 — Monolito modular](./0001-usar-monolito-modular.md).

## 1. Contexto y operación seleccionada

AudioShare permite crear salas y registrar receptores. Una operación futura candidata para procesamiento desacoplado es solicitar la sincronización de un receptor que se incorpora a una sala durante una reproducción activa. Se define el mensaje experimental receiver.sync.requested.

La sincronización que afecta a la reproducción actual necesita respuestas oportunas; no se debe interponer una cola en el camino crítico de play/pause sin mediciones que justifiquen la latencia adicional. Por ello, el experimento se mantiene aislado y no reemplaza el flujo de producción.

## 2. Alternativas consideradas

### A. Procesamiento síncrono en la API

**Ventajas:** implementación sencilla, respuesta inmediata con el resultado y menos componentes operativos.

**Desventajas:** el cliente espera al procesamiento; un fallo temporal puede afectar la respuesta HTTP; reintentos del cliente pueden repetir efectos si no existe idempotencia.

### B. Broker de mensajes durable

**Ventajas:** desacopla temporalmente productor y consumidor; según su configuración puede persistir mensajes, confirmar su aceptación y recuperar trabajo después de una interrupción; permite escalar consumidores por separado.

**Desventajas:** añade infraestructura, configuración, monitoreo y procedimientos operativos. No garantiza por sí solo procesamiento exactamente una vez; siguen siendo necesarias la idempotencia y la política de mensajes fallidos.

### C. Simulador local en memoria — elegido para el taller

**Ventajas:** sin servicios externos; pruebas deterministas de contrato, duplicados, fallos recuperables, backoff y dead letters; no altera el sistema productivo.

**Desventajas:** los mensajes pendientes y el registro de deduplicación se pierden al reiniciar; no representa durabilidad, concurrencia distribuida ni entrega entre máquinas.

## 3. Decisión

Usar un simulador local aislado para demostrar las propiedades solicitadas y **no incorporarlo al backend productivo en esta entrega**. Se conserva el flujo síncrono actual hasta que una necesidad de negocio y mediciones justifiquen operar una cola durable.

## 4. Contrato y compatibilidad

El mensaje V1 contiene schemaVersion, messageId, type (receiver.sync.requested), occurredAt, correlationId y payload.roomId, payload.receiverId y payload.targetPositionMs.

Se aceptan campos adicionales que no cambien la semántica de V1. Los campos obligatorios mantienen nombre y tipo; cambios incompatibles requieren una nueva versión y se rechazan si el consumidor no la soporta.

## 5. Garantía de entrega y consecuencias

El simulador reintenta el handler hasta tres intentos mientras el proceso permanece activo. La semántica es **entrega/procesamiento con posibles repeticiones**, no «exactamente una vez». Como la cola es en memoria, no se garantiza que un mensaje sobreviva al reinicio ni que se recupere un mensaje pendiente después de una caída.

El handler debe ser idempotente: un efecto podría haberse aplicado antes de que el consumidor falle y solicite un nuevo intento. Para producción, la deduplicación tendría que persistir junto con el efecto de negocio o utilizar una clave idempotente duradera.

## 6. Idempotencia y duplicados

La cola guarda en memoria los messageId confirmados correctamente. Si el mismo mensaje vuelve a publicarse, se registra message.duplicate y no se vuelve a invocar el handler. Esta garantía se limita a la vida del proceso.

## 7. Reintentos, backoff y dead letter

El máximo predeterminado es de tres intentos. Entre intentos se aplica backoff exponencial:

delayMs = baseBackoffMs * 2^(attempt - 1)

Con base de 10 ms, las esperas son 10 ms y 20 ms. Tras agotar los intentos, el mensaje se conserva en deadLetters con el número de intentos y el motivo final. En producción, la cola de fallidos y su procedimiento de reproceso tendrían que ser durables y operables.

## 8. Observabilidad

Cada registro incluye messageId y correlationId; según el evento incluye intento, demora, tiempo transcurrido y detalle del error. Los eventos message.produced, message.consumed, message.retry, message.acknowledged, message.duplicate y message.dead_letter permiten reconstruir el recorrido del mensaje.

## 9. Verificación y límites

Las pruebas automatizadas cubren duplicación, fallo recuperable, backoff exponencial, agotamiento de intentos, compatibilidad y trazabilidad. Deben ejecutarse con npm test -- tests/messaging-prototype.test.ts y npm run verify; esta ADR no afirma resultados de ejecución que no se hayan observado.

El prototipo no demuestra persistencia ante reinicios, procesamiento concurrente, entrega entre máquinas ni sincronización física del audio. Para producción se requerirían pruebas de recuperación, idempotencia durable, métricas operativas y una evaluación del impacto de latencia.
