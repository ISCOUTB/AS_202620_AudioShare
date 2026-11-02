# Amenazas priorizadas y mitigaciones

Elaborado el 2026-11-01 (entrega de la semana 13) sobre el repositorio en su
estado actual. Igual que en [`modos-de-fallo.md`](./modos-de-fallo.md), el
código se cita por archivo y nombre de manejador, sin números de línea.

## Método y alcance

- **Qué se analizó.** El backend (`src/app.ts`, `src/modules/*`,
  `src/shared/*`), el cliente Flutter (`lib/`), la interfaz web heredada
  (`public/app.js`), el despliegue (`Dockerfile`, `docker-compose.yml`,
  ADR-0008) y el CI (`.github/workflows/`).
- **Técnica.** STRIDE sobre las fronteras de confianza del diagrama C4 nivel 2:
  cliente ↔ API (HTTP/NDJSON), API ↔ disco (SQLite y pistas) y repositorio ↔
  CI/despliegue.
- **Evidencia.** `L` = lectura del código; **no se ejecutó un ataque** contra
  la instancia pública ni contra una local. `D` = ya documentado en otro
  documento del repositorio. Ninguna amenaza de esta tabla está reproducida con
  una prueba; al final se listan las pruebas que la convertirían en evidencia.
- **Contexto que cambia la prioridad.** La API está publicada en
  `https://audioshare.iscoutb.dev` (ADR-0008) y el cliente la usa por defecto
  (`ApiClient.publicServer`). NC-06 dice «incorporar autenticación antes de
  exponer el sistema fuera de la red local»: esa condición ya se cumplió, así
  que las amenazas de control de acceso dejan de ser teóricas.

## Activos

| Activo | Dónde vive | Qué se protege |
| --- | --- | --- |
| Estado de la sala (`status`, `startAt`, posición) | SQLite (`rooms`) | Integridad, disponibilidad |
| Participantes (`id`, rol, `joined_at`) | SQLite (`participants`) | Confidencialidad, integridad |
| Pista MP3 de cada sala | `data/tracks/<roomId>.mp3` | Integridad, disponibilidad, confidencialidad |
| Volumen `audioshare-data` | Dokploy | Disponibilidad (contiene base y pistas) |
| Mediciones de sincronía (EC-01) | Memoria (`SyncMeasurements`, `metrics`) | Integridad de la evidencia del proyecto |
| Cadena de suministro | `package-lock.json`, `pubspec.lock`, imagen Docker, GitHub Actions | Integridad |

## Cómo se puntúa

`Riesgo = Probabilidad × Impacto`, cada uno de 1 a 3.

- **Probabilidad.** 1: requiere condiciones poco comunes. 2: requiere
  conocimiento del sistema o estar en la red. 3: lo puede hacer cualquiera con
  la URL pública, sin herramientas especiales.
- **Impacto.** 1: molestia o dato de bajo valor. 2: pierde el control de una
  sala o expone sus datos. 3: deja el servicio caído o compromete a todas las
  salas.
- **Prioridad.** Alta: riesgo 6 a 9. Media: 3 a 5. Baja: 1 a 2.

Son juicios del equipo sobre un prototipo universitario, no mediciones. Si
cambia el alcance (por ejemplo, usuarios reales), hay que reevaluarlos.

## Tabla priorizada

| ID | STRIDE | Amenaza y ubicación | P | I | Riesgo | Prioridad | Evid. |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AM-03 | D, T | **Subida de pista sin autenticación ni cuota.** `POST /rooms/:roomId/track` acepta hasta 50 MB de cualquiera que conozca un `roomId`, sobrescribe la pista existente y no hay tope de espacio total. | 3 | 3 | 9 | Alta | L |
| AM-01 | S, E | **Sin autenticación ni autorización.** `POST /play`, `/pause`, `/audio`, `/track`, `/receivers` y `/ack` no identifican quién llama. El `emitterId` y el `receiverId` los inventa el cliente; CORS solo filtra navegadores y no es un control de acceso. | 3 | 2 | 6 | Alta | L, D (NC-06, FM-12) |
| AM-02 | I | **`GET /rooms` enumera todas las salas y sus participantes** sin autenticar. Entrega justo el `roomId` que AM-01 necesita. El endpoint no está en `docs/contracts/openapi.yaml` y el cliente Flutter no lo usa; solo lo prueba `tests/health.test.ts`. | 3 | 2 | 6 | Alta | L |
| AM-04 | D | **Sin límites de tasa ni de cantidad.** Se pueden crear salas, receptores y conexiones `stream` sin tope; cada uno ocupa memoria (`streams`, `coordinators`) o filas en SQLite. `client.send` tampoco controla la contrapresión (FM-10, FM-15). | 3 | 2 | 6 | Alta | L, D |
| AM-05 | T | **Cadena de suministro sin control automático.** El CI no ejecuta `npm audit` ni análisis de `pubspec`; no hay Dependabot; las acciones de GitHub están fijadas por etiqueta (`@v4`, `@v2`) salvo SonarCloud; las imágenes base (`node:22-alpine`, `flutter:3.35.7`) no están fijadas por digest; los rangos `^` de `package.json` admiten versiones nuevas al regenerar el lock. | 2 | 3 | 6 | Alta | L |
| AM-06 | S, T, I | **Transporte en claro permitido.** `android:usesCleartextTraffic="true"` en el manifiesto y el campo «Servidor» acepta `http://`. Quien esté en la misma red puede leer o alterar eventos `sync.start` y la pista. | 2 | 2 | 4 | Media | L |
| AM-07 | T | **Contenido de la pista poco validado.** Solo se comprueban 2 o 3 bytes iniciales (cabecera `ID3` o sincronía MPEG) en `POST .../track`. Cualquier archivo con esa cabecera se sirve con `audio/mpeg` y lo analiza `just_audio` en los receptores. | 2 | 2 | 4 | Media | L |
| AM-08 | T, R | **ACK y reloj falsificables.** `POST .../ack` toma `startedAt` y `offsetMs` del cliente sin autenticarlo; cualquiera puede registrar ACK de cualquier receptor y mover `spreadMs` y `maxSyncSpreadMs`. Afecta la credibilidad de la evidencia de EC-01. | 2 | 2 | 4 | Media | L, D (FM-06) |
| AM-14 | T | **XSS almacenado en la interfaz heredada.** `public/app.js` inserta `participant.id` con `innerHTML` y el servidor acepta cualquier cadena como `receiverId`. En producción se sirve Flutter Web (`build/web`), por lo que solo afecta cuando `public/` es el directorio servido (desarrollo sin compilar Flutter, pruebas). | 2 | 2 | 4 | Media | L |
| AM-09 | I | **Faltan cabeceras de seguridad.** No se desactiva `X-Powered-By`, no hay `X-Content-Type-Options: nosniff` ni política CSP. | 3 | 1 | 3 | Media | L |
| AM-11 | I | **Retención indefinida.** No hay `DELETE` de salas ni de pistas, ni caducidad. Las pistas y los identificadores de participantes se conservan mientras exista el volumen. Ver [`privacidad.md`](./privacidad.md). | 3 | 1 | 3 | Media | L |
| AM-13 | T | **Entradas sin validar.** `emitterId`, `receiverId` y `payload` no se validan en tipo ni longitud; `catch {}` en `POST .../receivers` responde 404 ante cualquier error (FM-07). | 3 | 1 | 3 | Media | L, D |
| AM-10 | D | **Pérdida del volumen sin respaldo.** «Fresh Volumes» o borrar la aplicación en Dokploy elimina base y pistas (FM-14). | 1 | 3 | 3 | Media | D |
| AM-12 | R | **Falta de trazabilidad.** Los registros de `play`, `ack` y `room.created` incluyen `roomId` pero no quién ni desde dónde; `trust proxy` no está configurado, así que detrás de Traefik la IP que ve Express sería la del proxy. | 2 | 1 | 2 | Baja | L |

STRIDE: S suplantación, T manipulación, R repudio, I divulgación de
información, D denegación de servicio, E elevación de privilegios.

## Mitigaciones asignadas

«Asignada a» indica el módulo o área donde se implementa. Se pone el área y no
una persona; el equipo reparte los nombres. «Tratamiento» es **mitigar**
(reducir con un control), **aceptar** (se documenta el riesgo residual) o
**transferir** (lo resuelve la plataforma o la operación).

| ID | Mitigación | Asignada a | Tratamiento | Esfuerzo | Estado |
| --- | --- | --- | --- | --- | --- |
| AM-03 | Exigir el token de emisor (AM-01) en `POST .../track`; fijar un límite de tamaño acorde a la pista de demostración (`public/audio/demo.mp3` pesa unos 470 KB) en lugar de 50 MB; rechazar la subida si el espacio libre del volumen baja de un umbral; borrar la pista al cerrar o caducar la sala (AM-11). | Audio + Session | Mitigar | M | Pendiente |
| AM-01 | Generar en `POST /rooms` un token aleatorio de emisor (32 bytes) y guardar solo su hash SHA-256 en SQLite; exigirlo como `Authorization: Bearer` en `play`, `pause`, `audio` y `track`. Dar un token de receptor al hacer `join`, exigido en `stream` y `ack`. Declarar el esquema en `openapi.yaml` y registrar la decisión en un ADR nuevo. | Session (+ contrato, + Flutter `ApiClient`) | Mitigar | L | Pendiente |
| AM-02 | Eliminar `GET /rooms` o restringirlo a `NODE_ENV !== "production"`; el código de sala pasa a ser el secreto de entrada. Actualizar `tests/health.test.ts`, que hoy lo prueba. | Session | Mitigar | S | Pendiente |
| AM-04 | Limitador de tasa por IP (en memoria, sin dependencia nueva, o `express-rate-limit`); topes por sala de receptores y conexiones `stream`; descartar conexiones cuyo buffer de escritura supere un umbral; configurar `trust proxy` para que la IP sea la real. En paralelo, límite en el proxy de Dokploy. | Session + Operación | Mitigar / Transferir (proxy) | M | Pendiente |
| AM-05 | Añadir `npm audit --omit=dev --audit-level=high` al CI; crear `.github/dependabot.yml` para `npm`, `pub`, `github-actions` y `docker`; fijar las acciones por SHA de commit; documentar la revisión de `flutter pub outdated` en cada entrega. Detalle en [`analisis-dependencias.md`](./analisis-dependencias.md). | CI / Operación | Mitigar | S | Pendiente |
| AM-06 | Mantener HTTPS como valor por defecto (ya lo es); mostrar un aviso en la pantalla de inicio cuando el servidor sea `http://`; dejar `usesCleartextTraffic` solo para builds de depuración o para el dominio de laboratorio. **Riesgo residual aceptado** para demostraciones en LAN, que necesitan `http://`. | Flutter | Mitigar parcialmente + Aceptar | S | Pendiente |
| AM-07 | Validar la estructura mínima del MP3 (cabecera de trama completa), enviar `X-Content-Type-Options: nosniff` y manejar los errores de decodificación en `JustAudioService` sin cerrar la sala. | Audio + Flutter | Mitigar | M | Pendiente |
| AM-08 | Incluir `startAt` en el ACK y responder 409 si no coincide (FM-06); ligar el ACK al token de receptor (AM-01); marcar en `/metrics` que el desfase es **autodeclarado** por los receptores. | Sync | Mitigar | M | Pendiente |
| AM-14 | Sustituir `innerHTML` por `textContent` (o escapar) en `public/app.js`; validar `receiverId` y `emitterId` en el servidor con una lista permitida (AM-13). | Web heredada + Session | Mitigar | S | Pendiente |
| AM-09 | `app.disable("x-powered-by")`; cabeceras `X-Content-Type-Options`, `Referrer-Policy` y una CSP para `build/web` (con prueba, porque Flutter Web puede requerir ajustes). | Backend (`app.ts`) | Mitigar | S | Pendiente |
| AM-11 | Caducidad de salas y pistas (el plazo lo fija el equipo, ver `privacidad.md`); `DELETE /rooms/:roomId` autenticado con el token de emisor. | Session + Audio | Mitigar | M | Pendiente |
| AM-13 | Validar `emitterId`/`receiverId` (cadena de 1 a 64 caracteres con `[A-Za-z0-9._-]`) y el tipo de `payload`; manejador de errores central que responda JSON; distinguir 404, 409 y 400 en `join`. | Session | Mitigar | S | Pendiente |
| AM-10 | Respaldo programado del volumen en Dokploy y una restauración de prueba. | Operación | Transferir | S | Pendiente |
| AM-12 | Registrar un identificador derivado del token (no el token) y la IP real en los eventos de control; conservar los registros un tiempo acotado. | Backend (`logger.ts`) | Mitigar | S | Pendiente |

## Controles que ya existen (y se conservan)

- Consultas SQL parametrizadas en `SQLiteRoomRepository` (sin concatenación de
  texto), lo que descarta inyección SQL por los identificadores.
- `AudioTrackStore.pathFor` solo admite `roomId` con `[a-f0-9-]`, lo que evita
  recorrer directorios; la escritura de la pista es atómica (ADR-0011).
- Los `roomId` son UUID v4 generados con `randomUUID()`: no se adivinan; el
  problema es que `GET /rooms` los publica (AM-02).
- Lista de orígenes permitidos para CORS, con valores distintos en producción.
- El contenedor corre como usuario sin privilegios (`USER audioshare`) y la
  imagen final no conserva las herramientas de compilación.
- `express.json()` mantiene su límite por omisión de 100 KB, que acota el
  `payload` de `/audio` aunque no esté configurado de forma explícita.
- `.env` está en `.gitignore` y `.env.example` no contiene secretos; el token
  de SonarCloud vive en los secretos del repositorio.

## Orden sugerido

1. **Rápidas y de alto retorno (S):** AM-02, AM-13 y AM-14 (comparten el
   mismo parche de validación), AM-09, AM-05.
2. **Con cambio de contrato (L/M):** AM-01 junto con AM-03 y AM-08, porque los
   tres dependen del mismo token. Va con ADR nuevo y cambios en
   `openapi.yaml`, en `ApiClient` y en las pruebas.
3. **Dependen de decisiones u operación:** AM-04 (valores de los límites),
   AM-11 (plazos de retención), AM-10 y el límite en el proxy (Dokploy).

## Pruebas que convertirían estas amenazas en evidencia

Todas se pueden escribir con `supertest` en `tests/`, sin tocar la instancia
pública:

- AM-01: `POST /rooms/:id/play` sin credenciales debe responder 401; hoy
  responde 200.
- AM-02: `GET /rooms` no debe devolver el listado en producción.
- AM-03: subir una pista mayor al límite fijado debe responder 413.
- AM-13 y AM-14: `receiverId` igual a `<img src=x onerror=alert(1)>` debe
  responder 400.
- AM-09: la respuesta no debe incluir `X-Powered-By`.

## Qué no cubre este análisis

- No hay pruebas de penetración ni escaneo de la instancia pública.
- Lo que haga Dokploy o Traefik (límites de conexión, cabeceras, registros) no
  se verificó; FM-10 ya señalaba lo mismo.
- El audio en vivo (micrófono) no existe aún; si se aprueba, hay que ampliar
  el análisis.
