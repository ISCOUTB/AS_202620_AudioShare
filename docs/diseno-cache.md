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

Los TTL de esta tabla son límites propuestos para una caché de servidor que **no existe**: el repositorio no tiene Redis ni caché en memoria. Lo que sí existe hoy es la caché HTTP descrita en «Caché implementada».

## Caché implementada (S12)

Contraste del 2026-10-25 con `src/app.ts`. La única caché real es la HTTP de la pista; no hay caché de servidor.

| Qué | Dónde | Cuánto | Invalidación tras una escritura |
|---|---|---|---|
| Pista MP3 de demostración, `GET /track` (archivo `public/audio/demo.mp3`) | Cliente e intermediarios (`Cache-Control: public, no-cache`) | Puede guardarse, pero **debe revalidarse en cada uso** con `ETag` / `Last-Modified` que Express calcula del archivo. Antigüedad máxima servida: 0. Una petición condicional vigente recibe 304 sin bytes | Si el archivo cambia en la misma URL, el cambio de `ETag` hace que la siguiente petición reciba la versión nueva. No hace falta invalidar ni versionar la URL |
| Pista MP3 de una sala, `GET /rooms/:roomId/track` | Ninguno (`Cache-Control: no-store`) | 0 | No aplica: nunca se guarda. Un reemplazo con `POST .../track` es visible en la siguiente descarga |
| Stream NDJSON, `GET /rooms/:roomId/stream/:receiverId` | Ninguno (`Cache-Control: no-cache`) | 0 | No aplica |

**Cambio de S12.** `GET /track` respondía `public, max-age=3600`: si se reemplazaba el archivo en la misma URL, los clientes podían reproducir el audio anterior hasta una hora. Se cambió a revalidación con `ETag`, que mantiene la ventaja de la caché (304 sin transferir los ~470 KB de `demo.mp3`) sin servir audio obsoleto.

**Política de invalidación vigente.** Para la pista, la invalidación es por revalidación (`no-cache` + `ETag`) en `/track` y por no cachear (`no-store`) en la pista de sala. Si en el futuro se quiere un `max-age` largo, la condición es servir la pista bajo una URL versionada (`/rooms/:roomId/track/{version}`) y no sobrescribir bytes bajo una URL ya cacheada.

**Pruebas:** `tests/consistency-cache.test.ts` comprueba la cabecera y el 304 de `/track`, y el `no-store` de la pista de sala.

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
