# Operaciones y garantías de consistencia

**Proyecto:** AudioShare. **Alcance:** Flutter, backend Node/Express y SQLite.  
**Nota:** diseño objetivo contrastado con el alcance descrito en README. Una garantía solo debe marcarse como implementada cuando el código y las pruebas la demuestren.

## Principios
1. SQLite es la fuente de verdad para salas, participantes y estado de reproducción persistido.
2. Las modificaciones del estado de una sala se validan y persisten en el backend antes de anunciar éxito.
3. Los eventos del stream notifican cambios, pero no sustituyen la lectura del estado persistido.
4. El MP3 es un objeto binario almacenado fuera de SQLite; su asociación con la sala requiere un protocolo de publicación y recuperación.
5. EC-01 (desfase ≤100 ms) y EC-02 (variación de latencia ≤200 ms) son objetivos de calidad, no garantías demostradas por la consistencia de la base de datos.

## Tabla operación → garantía

| Operación | Dato autoritativo | Garantía requerida | Mecanismo propuesto | Fallo/recuperación | Verificación |
|---|---|---|---|---|---|
| Crear sala | SQLite | Atomicidad: completa o inexistente | Insertar en transacción; devolver ID/código tras commit | No anunciar éxito si falla | Fallo de persistencia no deja sala parcial |
| Unirse a sala | Sala y participante en SQLite | Integridad y control de duplicados | Validar sala e insertar con restricción única apropiada | Reintento devuelve/reutiliza sesión según política | Repetir solicitud y probar sala inexistente |
| Consultar participantes | SQLite | Leer último estado confirmado | Consultar backend; no usar caché como autoridad | Error explícito si falla la lectura | Incorporación seguida de consulta |
| Play | Estado de reproducción en SQLite | Estado, posición y startAt coherentes | Guardar la transición atómicamente; publicar tras commit | Si falla DB, no publicar éxito | Evento coincide con lectura posterior |
| Pause | Estado de reproducción en SQLite | Transición ordenada y posición coherente | Calcular posición en backend y guardar posición/estado juntos | Reintento devuelve estado vigente | Pausa, lectura y reintento |
| Resume | Estado de reproducción en SQLite | Nueva referencia temporal coherente con posición | Guardar posición y nuevo startAt en una transición | No emitir evento antes del commit | Prueba pausa/reanudación |
| Consultar snapshot | SQLite | Snapshot de estado confirmado | Endpoint consulta estado actual; versión creciente si se implementa | Tras reconexión, obtener snapshot nuevo | Reconexión recupera estado correcto |
| Distribuir eventos | Estado confirmado en SQLite | Orden por sala y detección de pérdidas | Publicar tras commit; incluir versión por sala si se implementa | Al reconectar, leer snapshot; ignorar duplicados por versión | Orden, duplicados y reconexión |
| Subir MP3 | Archivo persistente + metadatos | No servir carga parcial | Escribir temporal, validar, renombrar y luego confirmar metadatos | Limpiar/reconciliar archivos huérfanos | Carga truncada y fallo de DB |
| Descargar MP3/Range | Archivo asociado a la sala | Integridad de bytes y aislamiento | Validar asociación y servir el objeto correcto | 404 si no hay pista; nunca servir otra sala | Comparar bytes y probar Range |
| Desconectar participante | Participante/presencia | Política explícita de presencia frente a pertenencia | Definir si desconectar elimina presencia o registro | Reconectar leyendo estado del servidor | Desconexión/reconexión |

## Alcance de las garantías
- **Transacción SQLite:** atomicidad para operaciones incluidas en una misma transacción.
- **Orden por sala:** requiere serialización o control de concurrencia explícito; no se presupone por usar SQLite.
- **Eventos:** consistencia eventual con el estado persistido; pueden perderse durante una desconexión.
- **Archivo + SQLite:** no comparten una transacción atómica. Se necesita publicación ordenada y reconciliación.
- **Audio:** consistencia del estado no demuestra desfase físico ≤100 ms; se requiere medición con equipos reales.

## Criterios de aceptación
1. Cada comando de reproducción exitoso coincide con el estado leído inmediatamente después.
2. Un error de persistencia no produce evento de éxito.
3. Un cliente que pierde el stream recupera el estado mediante snapshot.
4. Una pista incompleta nunca queda disponible.
5. Las pruebas separan garantías verificadas de objetivos pendientes.

El README describe SQLite para salas, participantes y estado, y MP3 en data/tracks con endpoints de subida/descarga. Antes de afirmar que cada garantía está implementada, comprobar el código y sus pruebas. En particular, no se declara aquí que el orden de eventos, la idempotencia, las restricciones únicas o la reconciliación de archivos huérfanos estén implementados sin evidencia concreta.
