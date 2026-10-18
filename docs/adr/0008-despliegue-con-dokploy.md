# 0008 — Desplegar con Dokploy a partir de `docker-compose.yml` (reemplaza el despliegue en Azure del ADR-0004)

- **Estado:** aceptado
- **Fecha:** 2026-10-13
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Reemplaza a:** [ADR-0004](./0004-despliegue-api-azure-vs-laboratorio.md), en lo relativo a dónde se ejecuta la API. El ADR-0004 no se reescribe: solo cambia su estado.
- **Escenario de calidad relacionado:** EC-01 — Sincronización inicial; EC-04 — Incorporación de nuevo receptor; restricción R-01 — Uso de herramientas gratuitas

## Contexto

El ADR-0004 eligió Azure Container Apps como entorno público principal y
dejó el servidor del laboratorio (contenedor con `docker-compose.yml` y
volumen persistente) como plan de reversión, con la misma imagen en ambos
casos.

El despliegue público activo hoy es otro: el README declara que la
aplicación corre en **Dokploy, con Docker Compose**, en
`https://audioshare.iscoutb.dev`. Esta decisión **se registra después de
ejecutarse**: el despliegue en Dokploy existía antes de este ADR, y la
revisión de S9 ya señalaba que la plataforma había cambiado sin alinear
los documentos.

Hechos verificados el 2026-10-13 sobre ese despliegue:

- `GET /health` respondió `status: ok` con los módulos `session`, `audio`
  y `sync`.
- `GET /time` respondió `serverTime` = 1791871626688, es decir
  2026-10-13T06:07:06Z en el reloj del servidor. Ese endpoint existe desde
  el commit `404947a`, así que el despliegue corre una versión posterior
  a ese commit.
- La URL se sirve por HTTPS y la aceptaron sin error dos clientes
  distintos (una herramienta de descarga y `Invoke-RestMethod`).
- La página raíz es el cliente legado `public/` («AudioShare | Demo A-01»),
  no Flutter Web: el `Dockerfile` no compila Flutter y `src/app.ts` solo
  sirve `build/web` si existe.

Configuración observada en el panel de Dokploy (v0.30.8), capturas del
2026-10-13:

- **Origen:** proveedor GitHub, repositorio `AS_202620_AudioShare`, rama
  `master`, ruta del compose `./docker-compose.yml`, disparador «On Push»
  y *Autodeploy* activado. Cada push a `master` genera un despliegue.
- **Dominio:** `audioshare.iscoutb.dev` apunta al servicio `api`, puerto
  3000, con HTTPS y certificado `letsencrypt` gestionado por Dokploy.
- **Respaldos de volumen:** ninguno configurado («No volume backups»).
- **Monitoreo:** el del servicio muestra 0 sin datos. El del servidor
  muestra su capacidad (11,67 GiB de RAM y 76,45 GB de disco) y, a las
  06:16 UTC del 2026-10-13, 2,47 % de CPU, 2,37 GiB de memoria y 21,75 GB
  de disco en uso. Es el uso de toda la máquina, no el de AudioShare.

## Alternativas consideradas

### A. Mantener Azure Container Apps (ADR-0004)

- **En contra:** no es el entorno que hoy atiende la URL pública; no se
  ha confirmado si el recurso de Azure sigue activo.

### B. Dokploy ejecutando `docker-compose.yml` del repositorio

- **A favor:** reutiliza el mecanismo de la alternativa A del ADR-0004
  (`docker-compose.yml` con el volumen `audioshare-data` montado en
  `/app/data`), sin código atado al proveedor; el archivo está versionado
  en el repositorio; `build: .` construye la imagen a partir del mismo
  `Dockerfile`.
- **En contra:** la configuración del panel de Dokploy (origen, rama,
  dominio, certificado) no está versionada, así que reproducir el
  despliegue depende del compose y de ese panel.
- **Se elige.**

## Decisión

La API se despliega en **Dokploy**, que construye y ejecuta el
`docker-compose.yml` del repositorio y la publica en
`https://audioshare.iscoutb.dev`. Azure Container Apps y el servidor del
laboratorio quedan como alternativas documentadas en
`docs/despliegue.md`, con la misma imagen.

## Consecuencias

- **Positivas:** URL pública estable y accesible; el mismo `Dockerfile` y
  `docker-compose.yml` sirven en cualquier máquina con Docker
  (`docker compose up -d --build`).
- **Persistencia:** el compose declara el volumen `audioshare-data`, y la
  base SQLite **sobrevivió a un redespliegue en producción**. Verificado el
  2026-10-18: tras un despliegue que cambió `src/`, `GET /health` informó
  `startedAt` = `2026-10-18T03:12:34.060Z` (el proceso se reinició) y la sala
  `959c5411-fbac-45d3-a003-575fbab822bb`, creada el 2026-10-13T06:30:44Z,
  siguió respondiendo 200. `GET /health` informa `startedAt`, lo que permite
  repetir la prueba; el procedimiento y el resultado están en
  `docs/despliegue.md`. No se probó la eliminación de la aplicación ni el
  reinicio del servidor.
  El volumen **no tiene respaldos configurados**, y el botón «Fresh
  Volumes» del panel no debe usarse salvo que se quiera empezar con la
  base vacía (por su nombre; no se probó).
- **Redespliegue automático:** como el disparador es «On Push», cada
  push a `master` genera un despliegue en el panel. Las duraciones
  observadas varían (2 s en unos, 1 min 15 s en otro), y el `Dockerfile`
  solo copia `package*.json`, `tsconfig.json`, `src/` y `public/`, por lo
  que un push que cambie solo documentación, pruebas o `lib/` no
  debería alterar la imagen. **No está verificado qué despliegues
  recrean el contenedor**; uno que sí lo haga corta las conexiones NDJSON
  abiertas. Por prudencia, no hacer push durante una demostración o
  sustentación; si hace falta, se puede desactivar *Autodeploy* en el
  panel.
- **Cliente servido:** la imagen no incluye Flutter Web; la URL pública
  sirve el cliente legado. Si se quiere publicar Flutter Web, el
  `Dockerfile` necesita una etapa de compilación.
- **Registro de imágenes:** `publish-image.yml` sigue publicando
  `vincexcard1916/audioshare-api:latest` en Docker Hub en cada push, pero
  el compose usa `build: .`, así que el despliegue en Dokploy no consume
  esa imagen. Queda como respaldo para el despliegue en Azure; conviene
  decidir si se mantiene.
- **Pendiente de confirmar (sin dato en el equipo):**
  - qué recurso físico o institucional aloja el servidor de Dokploy y
    quién lo administra;
  - consumo propio de AudioShare (el monitoreo del servicio no muestra
    datos);
  - costo y quién lo asume al salir del recurso académico;
  - si el servicio sigue activo fuera del periodo lectivo;
  - quién administra el DNS de `iscoutb.dev`.
  La documentación previa ya marcaba como `POR_CONFIRMAR` los datos del
  servidor del laboratorio (ver `docs/costos-mensuales.md`).
- **Riesgos y qué los dispararía:** (1) si la aplicación se elimina
  en el panel o se usa «Fresh Volumes», se pierde `data/audioshare.sqlite`
  y no hay respaldo → configurar un respaldo del volumen (la persistencia
  ante redespliegues ya se verificó el 2026-10-18); (2) si quien administra Dokploy retira
  el recurso, la URL deja de responder → volver a Azure o al servidor del
  laboratorio con la misma imagen.
- **Qué habría que revisar si cambia:** la latencia hacia el público
  objetivo no se ha medido sobre este entorno (EC-01 y EC-04); la medición
  de EC-01 hecha hasta ahora es del protocolo con receptores simulados
  (`docs/evidencia-a01-ec01.md`).

## Trazabilidad

- Requisito / aspecto: A-01 — Sincronización de reproducción de audio.
- Elementos C4 afectados: C4 Nivel 2 — Contenedores (`AppServer`,
  `SqliteDb`); ninguno cambia de forma, cambia dónde se ejecutan.
- Implementación: `docker-compose.yml`, `Dockerfile`,
  `.github/workflows/publish-image.yml`, `README.md` (sección
  «Despliegue mediante Dokploy»), `docs/despliegue.md`.
- Verificación: `GET /health` y `GET /time` contra la URL pública
  (2026-10-13).
