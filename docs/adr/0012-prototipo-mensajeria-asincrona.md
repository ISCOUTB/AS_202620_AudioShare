# ADR-0012: Evaluación de mensajería asíncrona mediante un prototipo aislado

- **Estado:** Propuesto para revisión del equipo.
- **Fecha:** 25 de octubre de 2026.
- **Contexto:** Taller académico de mensajería, idempotencia y reintentos.
- **Relación:** ADR-0001, selección del monolito modular.

## 1. Contexto

AudioShare permite crear salas y registrar dispositivos receptores. El proyecto cuenta con módulos que separan las responsabilidades de las sesiones, el audio y la sincronización.

Un escenario candidato para mensajería asíncrona es la incorporación de un receptor mientras existe una reproducción activa. En una implementación futura, se podría publicar un mensaje `receiver.sync.requested` para solicitar el procesamiento de su sincronización.

Actualmente, el sistema no utiliza una cola durable de mensajes. Incorporar un broker real añadiría infraestructura y responsabilidades operativas que deben justificarse según el alcance del proyecto.

## 2. Alternativas

### Alternativa A: procesamiento síncrono

La operación HTTP espera a que finalice el procesamiento.

**Ventajas:**
- Implementación sencilla.
- Menor complejidad operativa.
- El resultado se puede devolver directamente al cliente.

**Desventajas:**
- La solicitud espera a que termine el procesamiento.
- Un fallo temporal puede afectar la respuesta.
- Los reintentos del cliente pueden repetir operaciones si no existe idempotencia.

### Alternativa B: broker de mensajes

Se utiliza un sistema como RabbitMQ, Kafka o un servicio administrado.

**Ventajas:**
- Permite desacoplar temporalmente productor y consumidor.
- Puede ofrecer persistencia y mecanismos de confirmación según su configuración.
- Permite escalar el procesamiento de forma independiente.

**Desventajas:**
- Añade configuración e infraestructura.
- Requiere monitoreo y manejo de fallos.
- No elimina la necesidad de deduplicación e idempotencia.

### Alternativa C: simulador local

Se utiliza una cola en memoria para probar el contrato, los reintentos, los duplicados y los mensajes fallidos.

**Ventajas:**
- No requiere infraestructura externa.
- Permite realizar pruebas automatizadas.
- Mantiene aislado el experimento del backend de producción.

**Desventajas:**
- Los mensajes no son durables.
- No representa todos los comportamientos de un broker.
- La cola se pierde al reiniciar el proceso.

## 3. Decisión

Se propone utilizar un simulador local para realizar el taller, sin conectarlo al flujo de producción de AudioShare.

La decisión permite evaluar las propiedades solicitadas sin modificar la arquitectura actual ni introducir un servicio adicional.

## 4. Contrato y compatibilidad

El mensaje `receiver.sync.requested`, versión 1, contiene un identificador de mensaje, una fecha, un identificador de correlación y los datos de la sala y del receptor.

Se permiten cambios aditivos que mantengan la semántica de los campos existentes. Los cambios incompatibles requieren una nueva versión del contrato.

El consumidor rechaza las versiones desconocidas.

## 5. Garantía de entrega

El prototipo permite reintentar el procesamiento mientras el proceso permanece activo.

No garantiza la persistencia de mensajes ante reinicios y no ofrece entrega exactamente una vez.

## 6. Idempotencia

El simulador utiliza `messageId` para detectar mensajes que ya se procesaron correctamente.

La deduplicación se mantiene en memoria, por lo que no persiste entre reinicios.

## 7. Política de reintentos

Se permiten tres intentos por defecto.

El tiempo de espera aumenta exponencialmente según la fórmula:

`baseBackoffMs * 2^(intento - 1)`

Si el procesamiento falla en todos los intentos, el mensaje se guarda en `deadLetters`, junto con el número de intentos y el motivo del último fallo.

## 8. Observabilidad

Los eventos registrados incluyen `messageId`, `correlationId`, tipo de evento, número de intento, demora y tiempo transcurrido cuando corresponda.

Esto permite seguir el recorrido de un mensaje dentro del simulador.

## 9. Consecuencias y límites

El prototipo demuestra propiedades de la lógica de mensajería mediante pruebas automatizadas.

No demuestra persistencia ante reinicios, entrega entre máquinas, procesamiento concurrente ni sincronización física del audio.

Antes de incorporar mensajería a producción, el equipo tendría que evaluar la persistencia, la recuperación de mensajes fallidos, la deduplicación duradera, la integración con la API y las pruebas de carga.
