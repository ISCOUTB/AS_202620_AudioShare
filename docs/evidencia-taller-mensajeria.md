# Taller de mensajería asíncrona — AudioShare

## 1. Operación seleccionada

Se seleccionó como escenario experimental la solicitud de sincronización de un receptor que se incorpora a una sala.

El experimento se mantiene aislado porque el backend actual no utiliza una cola durable y el alcance del taller no requiere introducir un broker en producción.

## 2. Archivos entregados

- `experiments/messaging-prototype/contract.ts`: contrato del mensaje.
- `experiments/messaging-prototype/local-message-queue.ts`: simulador de cola.
- `tests/messaging-prototype.test.ts`: pruebas automatizadas.
- `docs/adr/0011-prototipo-mensajeria-asincrona.md`: decisión arquitectónica.
- `experiments/messaging-prototype/README.md`: instrucciones y límites.

## 3. Evidencia de ejecución

Ejecutar desde la raíz del repositorio:

`npm test -- tests/messaging-prototype.test.ts`

Después ejecutar:

`npm run verify`

**Resultado de las pruebas:** pendiente de completar con la salida real.

**Enlace al commit:** pendiente.

## 4. Propiedades evaluadas

- Validación del contrato.
- Rechazo de versiones incompatibles.
- Deduplicación por `messageId`.
- Reintentos ante fallos recuperables.
- Backoff exponencial.
- Registro de mensajes fallidos.
- Trazabilidad mediante `messageId` y `correlationId`.

## 5. Límites del experimento

La cola y el registro de deduplicación son volátiles y se pierden al reiniciar el proceso.

El procesamiento es secuencial y simulado. No se utiliza un broker real y no existe integración con los endpoints productivos.

El experimento no demuestra sincronización física del audio ni durabilidad de los mensajes.

## 6. Conclusión

El prototipo permite verificar mediante pruebas automatizadas el contrato, la deduplicación, los reintentos, el backoff y el manejo de mensajes fallidos.

Los resultados corresponden exclusivamente al simulador local y no deben extrapolarse a la disponibilidad o sincronización de la aplicación en producción.
