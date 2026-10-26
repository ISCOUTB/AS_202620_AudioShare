# Diseño de caché e invalidación

**Principio:** SQLite continúa siendo la fuente de verdad. La caché es opcional, derivada y descartable; su pérdida no debe impedir recuperar el estado correcto.

## Política por dato

| Dato | Política | Clave sugerida | TTL máximo de diseño | Invalidación |
|---|---|---|---|---|
| Estado de reproducción | No cachear en servidor inicialmente; snapshot efímero en cliente | room:{roomId}:playback | Cliente refresca al reconectar | Tras play/pause/resume; al reconectar, pedir snapshot |
| Participantes | Sin caché de servidor inicialmente | room:{roomId}:participants | N/A | Tras unirse/salir o cambiar presencia |
| Metadatos de sala | Caché opcional si mediciones la justifican | room:{roomId}:metadata | 30 s | Crear, cerrar o modificar sala; borrar tras commit |
| Código → ID de sala | Caché opcional | room-code:{code} | 60 s | Crear/cerrar/cambiar código; validar en SQLite |
| Metadatos de pista | Caché opcional | room:{roomId}:track | 60 s | Tras subir/reemplazar/eliminar pista |
| Bytes MP3 | No duplicar en caché de aplicación por defecto | ID/version de archivo | Según política HTTP explícita | Nueva versión/ETag al cambiar la pista |
| Eventos del stream | No son estado durable | room:{roomId}:event:{version} | Solo memoria de distribución | Snapshot al reconectar; no asumir replay |

Los TTL son límites propuestos, no afirmaciones de que el repositorio ya tenga Redis, caché en memoria o una política HTTP equivalente.

## Flujo de lectura y escritura
1. En una escritura, validar y persistir el cambio en SQLite.
2. Confirmar la transacción.
3. Invalidar las claves afectadas.
4. Publicar el evento a los clientes.
5. Si la caché falla, leer de SQLite; no confirmar escrituras usando datos cacheados.

En lectura: buscar clave; si está vigente, devolverla; en miss o expiración, leer SQLite y poblar caché. La caché nunca debe saltarse autorización ni validación de pertenencia a la sala.

## Invalidación
- **Play/pause/resume:** invalidar snapshot de reproducción de la sala después del commit.
- **Participantes:** invalidar después de confirmar incorporación/salida.
- **Pista reemplazada:** crear versión nueva; publicar archivo completo antes de actualizar metadatos; limpiar el anterior cuando no esté referenciado.
- **TTL:** limita la antigüedad si una invalidación se pierde, pero no reemplaza la invalidación para datos temporales.
- **Reconexión:** obtener snapshot nuevo antes de confiar en el estado local.
- **Errores:** falla de caché implica leer el origen; falla de SQLite no se disfraza devolviendo silenciosamente datos antiguos.

## Carreras y pruebas
Si se implementa caché compartida, usar versión del dato o clave versionada para evitar que una lectura antigua repueble la caché tras una invalidación. Para la primera versión, lo más seguro es no cachear estado de reproducción en servidor.

Pruebas recomendadas:
- Una lectura posterior a play/pause no devuelve el estado anterior.
- Una invalidación concurrente no permite repoblar con datos viejos.
- Reemplazar pista no entrega bytes parciales ni bytes de versión anterior bajo clave nueva.
- Una desconexión del stream seguida de reconexión obtiene snapshot vigente.

## Decisión incremental
No añadir Redis ni infraestructura adicional sin mediciones que lo justifiquen. Empezar con consultas SQLite y snapshots del cliente; cachear metadatos de lectura frecuente solo si el perfilado demuestra necesidad. Para reproducción sincronizada, la actualidad importa más que el porcentaje de aciertos.
