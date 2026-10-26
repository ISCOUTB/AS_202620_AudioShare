# Taller de mensajería asíncrona — AudioShare

## 1. Operación seleccionada

Se selecciona como escenario experimental la solicitud de sincronización de un receptor que se incorpora a una sala (receiver.sync.requested). La cola es un prototipo aislado: el backend productivo no usa esta cola y no se modifica su flujo de reproducción.

## 2. Archivos entregados

- experiments/messaging-prototype/contract.ts: contrato V1 y validación.
- experiments/messaging-prototype/local-message-queue.ts: cola local, deduplicación, reintentos, backoff, dead letters y logs.
- tests/messaging-prototype.test.ts: pruebas automatizadas.
- docs/adr/0012-prototipo-mensajeria-asincrona.md: decisión arquitectónica.
- experiments/messaging-prototype/README.md: instrucciones y límites.

## 3. Cómo verificar

Desde la raíz del repositorio, con dependencias instaladas:

```bash
npm ci
npm test -- tests/messaging-prototype.test.ts
npm run verify
```

No se requiere RabbitMQ, Docker ni un servicio externo para ejecutar el prototipo.

**Evidencia de ejecución:** debe registrarse a partir de la salida real de los comandos anteriores; no se afirma que una ejecución haya ocurrido si no se ha ejecutado en el entorno del equipo.

## 4. Contrato, entrega y compatibilidad

El contrato contiene schemaVersion, messageId, type, occurredAt, correlationId y el payload con sala, receptor y posición objetivo. El consumidor acepta campos adicionales compatibles, pero rechaza versiones desconocidas.

La semántica es de reintento con procesamiento potencialmente repetido, no de «exactamente una vez». Mientras el proceso siga activo, el simulador reintenta errores del consumidor hasta tres intentos por defecto. La cola es volátil: un reinicio puede perder mensajes pendientes y el registro de deduplicación.

## 5. Pruebas automatizadas

- Mensaje duplicado: el handler se ejecuta una sola vez para el mismo messageId.
- Fallo recuperable: tras el primer fallo, se reintenta y se confirma el mensaje.
- Backoff exponencial: los retardos para tres intentos son 10 ms y 20 ms en la prueba controlada.
- Fallo persistente: tras agotar intentos, el mensaje queda en deadLetters.
- Compatibilidad: se aceptan campos adicionales; se rechaza una versión desconocida.
- Trazabilidad: message.produced, message.consumed, message.retry y message.dead_letter conservan messageId y correlationId.

## 6. Comparación arquitectónica

El procesamiento síncrono es más simple y permite devolver el resultado directamente, pero mantiene la solicitud esperando y acopla el fallo del procesamiento a la respuesta. Un broker durable desacoplaría productor y consumidor y permitiría recuperación según su configuración, a costa de infraestructura y operación adicionales. El simulador local permite probar la lógica requerida sin introducir esa complejidad, pero no acredita durabilidad.

## 7. Límites y conclusión

El prototipo es secuencial, en memoria y no está integrado con los endpoints productivos. No demuestra recuperación después de reinicios, entrega entre máquinas ni sincronización física del audio. La decisión de no incorporarlo a producción se documenta en el [ADR-0012](adr/0012-prototipo-mensajeria-asincrona.md).
