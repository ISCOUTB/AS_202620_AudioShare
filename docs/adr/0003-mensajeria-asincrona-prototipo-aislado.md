# ADR-0003: Prototipo aislado de mensajería asíncrona

- **Estado:** Aceptado para el taller; no incorporado al runtime.
- **Fecha:** 2026-10-25
- **Contexto:** AudioShare transmite audio en tiempo real. Encolar la ruta de audio o los comandos de reproducción introduciría latencia y podría procesar comandos obsoletos. No se justifica un broker en esa ruta.
- **Decisión:** Probar el evento de auditoría room.created con un simulador local aislado. No se conecta a la aplicación ni es un broker de producción.
- **Alternativa síncrona:** Escribir la auditoría antes de responder es más simple y permite propagar fallos inmediatamente, pero acopla latencia y disponibilidad del endpoint al destino de auditoría.
- **Entrega:** Se asume at-least-once y posibles duplicados. No se afirma exactly-once ni durabilidad frente a reinicios porque la cola es en memoria.
- **Contrato:** messageId, schemaVersion=1, eventType=room.created, occurredAt, roomId y producerId. Se permiten campos opcionales aditivos; cambios incompatibles requieren nueva versión. Versiones o tipos desconocidos se rechazan.
- **Idempotencia:** messageId sirve para deduplicar. En producción, los IDs procesados deben persistirse junto con el efecto en una transacción o restricción única.
- **Reintentos:** 3 intentos como máximo, con backoff de 100 ms y 200 ms; agotado el límite, se mueve a dead-letter. El prototipo omite jitter y persistencia.
- **Consecuencias:** Es verificable sin servicios externos, pero no soporta reinicios ni varios procesos. No debe usarse en producción.
- **Evidencia:** tests/messaging-prototype.test.ts prueba duplicados y recuperación tras fallo transitorio.
- **Observabilidad:** logs con messageId, etapa, intento, timestamp y detalle permiten seguir productor, reintentos y consumidor.
