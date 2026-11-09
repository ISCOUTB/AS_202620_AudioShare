# ADR-0013 — Código de sala de 6 dígitos y caducidad por inactividad

- **Estado:** aceptado (implementado y probado en local; pendiente de desplegar)
- **Fecha:** 2026-11-09
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Relación:** [ADR-0011 — Separar estado y archivos de audio](./0011-fuente-de-verdad-y-almacenamiento-de-pistas.md); amenazas AM-02, AM-04, AM-11 y AM-13 en `docs/amenazas-priorizadas.md`
- **Aspecto:** A-01 — Sincronización de reproducción de audio

## Contexto y problema

El código de sala era un UUID de 36 caracteres: imposible de dictar o teclear en un celular. Además, las salas y sus pistas MP3 no se borraban nunca (AM-11): el volumen crecía sin límite y, el 2026-11-08, `POST /rooms` en producción empezó a responder 500 mientras las lecturas seguían funcionando, un síntoma compatible con un volumen sin espacio (causa **no confirmada**: el panel de Dokploy no estaba disponible). Pedir códigos más cortos empeora la seguridad: con 6 dígitos hay un millón de combinaciones y `GET /rooms` publicaba todas las salas.

## Decisión

1. **Código de 6 dígitos**, generado con `crypto.randomInt`, con ceros a la izquierda (se guarda como texto). Se reintenta hasta 20 veces si el código ya existe. Las salas con UUID anteriores siguen funcionando.
2. **Caducidad por inactividad:** una sala sin actividad durante `ROOM_TTL_HOURS` (24 por defecto; 0 la desactiva) se borra junto con su pista y su estado en memoria. Cuenta como actividad cualquier petición a una ruta con `:roomId` (registrada como máximo una vez por minuto). Una sala con receptores conectados por `stream` no se borra. La búsqueda corre cada 10 minutos y 30 segundos tras arrancar.
3. **Contra la fuerza bruta:** cada origen puede consultar hasta 20 códigos inexistentes por minuto; superado el tope recibe 429 con `Retry-After`, incluso con un código válido. `TRUST_PROXY=1` hace que el origen sea la IP del cliente y no la del proxy.
4. **`GET /rooms` cerrado en producción** (404) salvo `EXPOSE_ROOM_LIST=true` (AM-02).
5. **Nombres elegidos por el usuario:** 1 a 30 caracteres, sin espacios al borde ni caracteres de control; se rechazan con 400. Si el cliente no envía nombre, el servidor genera uno (clientes anteriores).
6. **Regreso del emisor:** `POST /rooms/:roomId/emitter` con el nombre con el que creó la sala; otro nombre recibe 403.
7. **Errores siempre en JSON:** un último manejador responde 400, 413, 503 (fallo de SQLite) o 500, y `/health` informa `storage` (`ok` o `error`) con una escritura de prueba, manteniendo HTTP 200 para que el healthcheck de Docker mida solo que el proceso vive.

## Consecuencias

- Una sala dura, como máximo, 24 horas desde su última actividad; la pista subida se pierde con ella. Es deliberado (privacidad y espacio) y debe decirse a los usuarios.
- **Riesgo aceptado:** un millón de códigos no es un secreto fuerte. Con los tres controles anteriores, adivinar un código exige superar el límite de intentos y acertar dentro de la ventana de vida de la sala. No sustituye a un token de emisor (AM-01), que sigue pendiente.
- **Riesgo aceptado:** el emisor se reconoce por su nombre, igual que hoy cualquiera que conozca el código puede llamar a `play` y `pause` (AM-01).
- **Operación:** sin `TRUST_PROXY` detrás de Traefik, todos los clientes comparten una IP y un atacante podría bloquear a los demás; está definido en `docker-compose.yml`.
- El límite de intentos vive en memoria del proceso: se reinicia con el servicio y no se comparte entre instancias.
- Se descarta mostrar el código en minúsculas o con guiones, y usar letras: dictarlo por teléfono con solo dígitos es más simple.
- `DELETE /rooms/:roomId` sigue pendiente porque sin token cualquiera podría borrar una sala ajena.
