# 0004 — Desplegar la API en Azure Container Apps (Azure for Students), con el servidor del laboratorio como respaldo sin tarjeta

- **Estado:** aceptado
- **Fecha:** 2026-09-28
- **Decide:** equipo AudioShare (AS_202620_AudioShare)
- **Escenario de calidad relacionado:** EC-01 — Sincronización inicial; EC-04 — Incorporación de nuevo receptor; restricción R-01 — Uso de herramientas gratuitas

## Contexto

La pieza a desplegar es la API (proceso Node.js/Express que expone REST
para gestión de sala y un stream NDJSON de eventos de reproducción —
ver ADR-0002), con persistencia embebida en SQLite (`better-sqlite3`,
archivo `data/audioshare.sqlite`).

Dos hechos de la Guía de despliegue y costos del curso aplican directo:

1. **Esta pieza no es candidata a función serverless.** El endpoint
   `GET /rooms/:roomId/stream/:receiverId` mantiene una conexión HTTP
   abierta (NDJSON, `Connection: keep-alive`) mientras el receptor esté
   en la sala — exactamente el caso "API con conexión persistente" que
   la guía descarta para funciones. Esta comparación es entre dos
   formas de ejecutar un proceso persistente, no función-vs-contenedor.
2. **SQLite embebido significa que la persistencia vive en el disco
   del mismo proceso.** Cualquier plataforma que no garantice disco
   persistente pierde `data/audioshare.sqlite` en cada reinicio.

R-01 exige herramientas gratuitas; ninguna cuenta de pago es
obligatoria en el curso. Un integrante del equipo (Vincent Cardona)
está matriculado en la Universidad Tecnológica de Bolívar y activó
**Azure for Students** el 2026-09-27: acceso verificado por correo
institucional, sin tarjeta de crédito, con $100 USD de crédito por 12
meses. La concesión mensual de Azure Container Apps (180.000 vCPU-s,
360.000 GiB-s y 2 M de solicitudes) se consultó en la página de
precios del servicio el 2026-09-27 y se anota como dato a reverificar
antes de la sustentación, porque estas ofertas cambian sin aviso.

## Alternativas consideradas

### A. Servidor del laboratorio (contenedor Docker con volumen persistente)

Se construye la imagen con el `Dockerfile` de este repositorio y se
levanta con `docker compose up -d --build` (ver `docker-compose.yml`),
con `data/` montado como volumen.

- **A favor:** disco persistente real → SQLite sobrevive a un
  reinicio; sin tarjeta bajo ninguna circunstancia; el equipo controla
  el entorno completo; sin "sleep" por inactividad, así que EC-04
  (receptor nuevo se sincroniza en ≤3 s) no depende de un arranque en
  frío del proceso.
- **En contra:** depende de que el laboratorio confirme (dato marcado
  `POR_CONFIRMAR` en la Guía de despliegue) si el servidor abre
  puertos accesibles desde fuera de la red UTB, cuánto disco hay
  asignado por equipo, y si el proceso persiste fuera del periodo
  lectivo. La URL pública es requisito del curso, y hoy no está
  confirmado que esta alternativa pueda cumplirlo.
- **Por qué se mantiene como opción:** es la única alternativa que no
  depende de una cuenta externa ni de una tarjeta, y es el plan de
  reversión si Azure deja de estar disponible.

### B. Azure Container Apps (suscripción Azure for Students)

Se despliega la misma imagen (`Dockerfile` sin modificar) como
Container App dentro de un Container Apps Environment, en el plan de
Consumo, con `minReplicas: 0`.

- **A favor:** URL pública HTTPS por defecto (`*.azurecontainerapps.io`),
  accesible desde fuera de la red UTB; puede escalar a cero réplicas
  cuando no hay tráfico; soporta contenedor Docker propio; la
  concesión gratuita mensual no depende del crédito de $100 (dato
  a reverificar, ver Contexto).
- **En contra:** sin volumen montado, el almacenamiento local es
  efímero por réplica (mismo riesgo de pérdida de
  `data/audioshare.sqlite` que en cualquier plataforma sin disco
  persistente); el arranque en frío tras escalar a cero compite con
  EC-04; requiere que el resto del equipo tenga acceso a la
  suscripción o active la suya para poder redesplegar sin depender de
  una sola persona (criterio 7 de la guía).
- **Por qué se elige:** es la única alternativa que hoy produce una
  URL pública comprobable desde fuera de la universidad, sin tarjeta.

**Alternativa descartada explícitamente: Render (plan Free).** Se
consideró en una iteración anterior. Se descarta porque, con acceso ya
verificado a Azure for Students sin tarjeta, evita mantener dos
ecosistemas de despliegue distintos para las alternativas A y B.

## Restricciones verificadas al desplegar (evidencia real)

Estas restricciones aparecieron al ejecutar el despliegue el
2026-09-28 y cambiaron el procedimiento respecto del plan inicial:

1. **Regiones limitadas.** La política `sys.regionrestriction` de la
   suscripción solo permite `chilecentral`, `mexicocentral`,
   `canadacentral`, `belgiumcentral` y `spaincentral`. Desplegar en
   `eastus` y `eastus2` falló con `RequestDisallowedByAzure`. Se
   despliega en `canadacentral`.
2. **ACR Tasks bloqueado.** `az containerapp up --source .` falló con
   `TasksOperationsNotAllowed`, así que no se puede construir la
   imagen dentro de Azure.
3. **GitHub Container Registry no sirvió.** La organización ISCOUTB
   deshabilita la visibilidad pública de paquetes (el paquete quedó
   como `internal`) y Azure recibió `403 Forbidden` al bajar la imagen
   con credenciales de un token de lectura, aunque el mismo token sí
   obtenía acceso desde una máquina local.
4. **Solución adoptada.** La imagen se construye en GitHub Actions
   (`.github/workflows/publish-image.yml`) y se publica en un
   repositorio público de Docker Hub
   (`vincexcard1916/audioshare-api`); Azure la descarga sin
   credenciales. El repositorio de código ya es público y la imagen no
   contiene secretos: las variables de entorno se inyectan desde el
   proveedor.

## Decisión

Se despliega la API en **Azure Container Apps**, región
`canadacentral`, bajo la suscripción Azure for Students de un
integrante del equipo, con la imagen publicada en Docker Hub. El
**servidor del laboratorio** sigue siendo la alternativa sin tarjeta y
el plan de reversión. Ambas alternativas usan la misma imagen Docker,
lo que hace barata la reversión (criterio 6 de la guía).

Verificación del despliegue: el 2026-09-28T04:19:17Z,
`GET /health` respondió `http=200 tiempo=1.909s` en
`https://audioshare-api.icypond-27a6987e.canadacentral.azurecontainerapps.io`.

## Consecuencias

- **Positivas:** URL pública reproducible; mismo `Dockerfile` para ambas
  alternativas, sin código atado al proveedor; construcción de la
  imagen versionada como workflow en el repositorio.
- **Negativas / costos asumidos:** pérdida de datos de
  `data/audioshare.sqlite` en cada reinicio o escalado a cero — mismo
  riesgo de cualquier plataforma sin disco persistente; dependencia de
  que la suscripción del integrante siga activa; dependencia de una
  cuenta personal de Docker Hub para el registro; el paso de despliegue
  a Azure es manual (`az containerapp update`); la región
  `canadacentral` está lejos del público objetivo, lo que puede sumar
  latencia a EC-01 y EC-04 (no medido).
- **Riesgos y qué los dispararía:** (1) la suscripción se suspende o el
  crédito se agota → migrar a la alternativa A con la misma imagen.
  (2) el equipo necesita persistencia entre sesiones de demo → montar
  Azure Files como volumen o migrar a una base gestionada, decisión que
  merece su propio ADR. (3) el arranque en frío tras escalar a cero
  supera el objetivo de EC-04 → subir `minReplicas` a 1 (rompe el tramo
  gratuito según `docs/costos-mensuales.md`).
- **Qué habría que revisar si cambia:** si el sistema deja de tratar las
  salas como efímeras, la pérdida de disco deja de ser un costo
  aceptable; si la organización habilita paquetes públicos, se puede
  volver a GitHub Container Registry.

## Trazabilidad

- Requisito / aspecto: A-01 — Sincronización de reproducción de audio.
- Elementos C4 afectados: C4 Nivel 2 — Contenedores (`AppServer`,
  `SqliteDb`); ninguno cambia de forma, cambia dónde se ejecutan.
- Implementación: `Dockerfile`, `docker-compose.yml`,
  `.github/workflows/publish-image.yml`, `docs/despliegue.md`.
- Pruebas que lo cubren: `GET /health` y `GET /metrics` verificados
  contra la URL pública (ver `docs/despliegue.md`).