# Taller: mensajería asíncrona verificable

## Operación seleccionada
La transmisión de audio y los comandos de reproducción no se encolan porque son sensibles a la latencia. Para cumplir el taller sin introducir un broker injustificado, se implementó un prototipo aislado para el evento de auditoría room.created. No se invoca desde el runtime de AudioShare.

## 1. Contrato del mensaje
```json
{
  "messageId": "evt-001",
  "schemaVersion": 1,
  "eventType": "room.created",
  "occurredAt": "2026-10-25T12:00:00.000Z",
  "roomId": "room-42",
  "producerId": "api"
}
```
messageId es el ID de deduplicación; schemaVersion identifica el contrato; eventType identifica el evento; occurredAt es ISO-8601; roomId y producerId referencian el origen. Se permiten campos opcionales aditivos. Cambios incompatibles requieren una nueva versión.

## 2. Garantía
Se modela entrega al menos una vez: un mensaje puede procesarse más de una vez tras un fallo. No se promete exactly-once. El simulador es en memoria y no garantiza supervivencia a reinicios.

## 3. Idempotencia
Publicar dos veces el mismo messageId no crea dos elementos pendientes. El consumidor registra IDs procesados. En producción, ese registro debe persistirse atómicamente con el efecto de negocio.

## 4. Reintentos y fallidos
Máximo 3 intentos; backoff de 100 ms y 200 ms. Tras agotar intentos, el mensaje pasa a dead-letter con el último error. No hay jitter ni persistencia: son límites explícitos del prototipo.

## 5. Pruebas automatizadas
Ejecutar: `npm test -- tests/messaging-prototype.test.ts`. Las pruebas verifican un duplicado y un fallo recuperable que se reintenta y termina correctamente.

## 6. Trazabilidad
Cada log tiene messageId, stage, attempt, timestamp y detail opcional. Las etapas son published, consumed, duplicate, retry y dead-letter. En producción se medirían tasa de reintentos, cantidad de dead-letter y antigüedad del mensaje más antiguo.

## 7. Comparación con alternativa síncrona
| Criterio | Síncrono | Prototipo asíncrono |
|---|---|---|
| Respuesta | Espera la auditoría | Encola y procesa después |
| Fallo | Se propaga de inmediato | Reintenta |
| Acoplamiento | Productor y auditoría disponibles a la vez | Procesamiento desacoplado en el tiempo |
| Duplicados | Menor exposición a reintentos, no imposible | Posibles; se deduplican por ID |
| Complejidad | Baja | Mayor |
| Durabilidad | Depende del almacenamiento síncrono | No disponible en este simulador |

## Archivos
- Implementación: prototypes/messaging-queue.ts
- Pruebas: ../tests/messaging-prototype.test.ts
- Decisión: adr/0003-mensajeria-asincrona-prototipo-aislado.md
