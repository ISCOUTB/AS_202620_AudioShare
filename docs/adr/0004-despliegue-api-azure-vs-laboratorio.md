# 0004 — Desplegar la API en Azure Container Apps (Azure for Students), con el servidor del laboratorio como respaldo sin tarjeta

- **Estado:** propuesto
- **Fecha:** 2026-09-27
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

## Alternativas consideradas

### A. Servidor del laboratorio (contenedor Docker con volumen persistente)

Se construye la imagen con el `Dockerfile` de este repositorio y se
levanta con `docker compose up -d --build` (ver `docker-compose.yml`),
con `data/` montado como volumen.

- **A favor:** disco persistente real → SQLite sobrevive a un
  reinicio; sin tarjeta bajo ninguna circunstancia; el equipo controla
  el entorno completo; sin límite de "sleep" por inactividad, así que
  EC-04 (receptor nuevo se sincroniza en ≤3 s) no depende de un
  arranque en frío del proceso.
- **En contra:** depende de que el laboratorio confirme (dato marcado
  `POR_CONFIRMAR` en la Guía de despliegue) si el servidor abre
  puertos accesibles desde fuera de la red UTB, cuánto disco hay
  asignado por equipo, y si el proceso persiste fuera del periodo
  lectivo.
- **Por qué se mantiene como opción:** es la única alternativa que no
  depende en absoluto de una cuenta externa ni de una tarjeta, ni
  siquiera para verificación — satisface sin ambigüedad el requisito
  "al menos una sin tarjeta" independientemente de que el crédito de
  Azure exista o no.

### B. Azure Container Apps (suscripción Azure for Students)

Se despliega la misma imagen (`Dockerfile` sin modificar) como
Container App dentro de un Container Apps Environment, en el plan de
Consumo.

- **A favor:** URL pública HTTPS por defecto (`*.azurecontainerapps.io`),
  accesible desde fuera de la red UTB; healthcheck configurable como
  *probe* del propio servicio; **la concesión gratuita de Container
  Apps (180.000 vCPU-s, 360.000 GiB-s y 2 M de solicitudes por mes) es
  perpetua y no depende del crédito de $100** — a diferencia de una VM
  o de App Service, que si se agota el crédito empiezan a facturar;
  puede escalar a cero réplicas cuando no hay tráfico, así que no
  desperdicia crédito en tiempo muerto; soporta contenedor Docker
  propio sin restricciones de plan gratuito (a diferencia de App
  Service F1, que en la práctica está pensado para código, no
  contenedores propios).
- **En contra:** el registro (Azure Container Registry o Docker Hub) y
  el propio servicio de Container Apps añaden superficie de
  configuración (grupo de recursos, entorno, registro) frente a
  Render, que solo pedía un `render.yaml`; sin volumen montado, el
  almacenamiento local también es efímero por réplica — mismo riesgo
  de pérdida de `data/audioshare.sqlite` que ya se había documentado
  con Render; requiere que el resto del equipo pueda acceder a la
  suscripción de Azure for Students del integrante que la activó (o
  activar la suya propia) para poder redesplegar sin depender de una
  sola persona — criterio 7 de la guía.
- **Por qué se elige:** al no depender del consumo del crédito de
  estudiante para permanecer gratis, es más sostenible para el resto
  del semestre que una cuenta con capa gratuita ligada solo a bajo
  volumen (Render) — y ya no exige buscar una alternativa "sin
  tarjeta" aparte, porque Azure for Students tampoco la pidió.

**Alternativa descartada explícitamente: Render (plan Free).** Se
consideró en una iteración anterior de este ADR. Se descarta porque,
teniendo ya acceso verificado a Azure for Students sin tarjeta, Azure
Container Apps ofrece una capa gratuita perpetua por diseño del
servicio (no un crédito que se agota) y evita mantener dos ecosistemas
de despliegue distintos para las alternativas A y B.

## Decisión

Se despliega la API en **Azure Container Apps**, bajo la suscripción
Azure for Students de un integrante del equipo, como entorno accesible
públicamente para la sustentación. El **servidor del laboratorio**
sigue siendo la alternativa sin tarjeta y el plan de reversión si la
suscripción de Azure deja de estar disponible para el equipo. Ambas
alternativas usan la misma imagen Docker — es lo que hace barata la
reversión (criterio 6 de la guía).

## Consecuencias

- **Positivas:** URL pública reproducible en minutos; capa gratuita
  perpetua, no ligada al crédito de $100; el mismo Dockerfile sirve
  para ambas alternativas, sin código atado al proveedor; el pipeline
  puede desplegar automáticamente en cada push a `main` vía GitHub
  Actions con `azure/container-apps-deploy-action`.
- **Negativas / costos asumidos:** pérdida de datos de
  `data/audioshare.sqlite` en cada reinicio/escalado a cero de la
  réplica — mismo riesgo que ya existía con Render, se documenta aquí
  de nuevo porque no desaparece por cambiar de proveedor. Dependencia
  de que la cuenta de Azure for Students del integrante siga activa
  (renovación anual, estado de matrícula en la UTB).
- **Riesgos y qué los dispararía:** (1) la suscripción de Azure for
  Students se suspende o el crédito se agota antes de tiempo por un
  uso indebido de otros recursos de Azure fuera de este proyecto → se
  migra a la alternativa A, redesplegando la misma imagen sin cambios
  de código. (2) el equipo necesita persistencia real entre sesiones
  de demo → montar Azure Files como volumen del Container App, o
  migrar a una base gestionada — decisión que merece su propio ADR.
- **Qué habría que revisar si cambia:** si el sistema deja de tratar
  las salas como efímeras, la pérdida de disco en cada escalado a cero
  deja de ser un costo aceptable y esta decisión debe revisarse.

## Trazabilidad

- Requisito / aspecto: A-01 — Sincronización de reproducción de audio.
- Elementos C4 afectados: C4 Nivel 2 — Contenedores (`AppServer`,
  `SqliteDb`); ninguno cambia de forma, cambia dónde se ejecutan.
- Implementación: `Dockerfile`, `docker-compose.yml`,
  `.github/workflows/deploy-azure.yml`.
- Pruebas que lo cubren: `GET /health` verificado manualmente contra
  la URL pública tras cada despliegue (ver `docs/despliegue.md`).
