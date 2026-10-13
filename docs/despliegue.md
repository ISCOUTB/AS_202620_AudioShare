# Despliegue de la API

## Estado actual: Dokploy (ADR-0008)

La API corre en Dokploy, que construye y ejecuta el `docker-compose.yml`
del repositorio, en `https://audioshare.iscoutb.dev`. Decisión en
`docs/adr/0008-despliegue-con-dokploy.md`.

Reproducir el entorno en cualquier máquina con Docker:

```bash
docker compose up -d --build
curl -sS http://localhost:3000/health
curl -sS http://localhost:3000/time
```

### Configuración en el panel de Dokploy (capturas del 2026-10-13)

- Origen: GitHub, repositorio `AS_202620_AudioShare`, rama `master`,
  `./docker-compose.yml`, disparador «On Push», *Autodeploy* activado.
- Dominio: `audioshare.iscoutb.dev` → servicio `api`, puerto 3000, HTTPS,
  certificado `letsencrypt`.
- Respaldos de volumen: ninguno configurado.
- Monitoreo del servicio: 0 sin datos. Capacidad del servidor: 11,67 GiB
  de RAM y 76,45 GB de disco (uso global de la máquina a las 06:16 UTC:
  2,47 % de CPU, 2,37 GiB de memoria, 21,75 GB de disco; no es el consumo
  de AudioShare).

**Cuidado:** cada push a `master` redespliega y corta las conexiones
abiertas. No hacer push durante una demostración o sustentación.

### Verificación contra la URL pública, con hora

Ejecutada el 2026-10-13 desde Windows con `Invoke-RestMethod`:

```powershell
Invoke-RestMethod https://audioshare.iscoutb.dev/health
# status=ok  system=AudioShare  modules={session, audio, sync}
Invoke-RestMethod https://audioshare.iscoutb.dev/time
# serverTime=1791871626688  (2026-10-13T06:07:06Z, reloj del servidor)
```

`/time` solo existe desde el commit `404947a`, así que el despliegue
corre una versión posterior.

### Prueba de persistencia (pendiente)

El compose monta el volumen `audioshare-data` en `/app/data`, pero la
persistencia en producción no se ha verificado. Procedimiento:

```powershell
$r = Invoke-RestMethod -Method Post https://audioshare.iscoutb.dev/rooms -ContentType 'application/json' -Body '{"emitterId":"emitter-persistencia"}'
$r.roomId
# forzar un redeploy en Dokploy (o hacer push a master) y luego:
Invoke-RestMethod https://audioshare.iscoutb.dev/rooms/<roomId>
```

Si la sala sigue respondiendo después del redeploy, el volumen persiste.
Registrar aquí el resultado con fecha.

### Limitaciones conocidas

- La imagen no compila Flutter: la URL pública sirve el cliente legado
  `public/`, no Flutter Web.
- `publish-image.yml` publica una imagen en Docker Hub que el despliegue
  en Dokploy no consume (el compose usa `build: .`).
- El volumen `audioshare-data` no tiene respaldos configurados.
- Servidor, consumo propio, costo y responsable: pendientes de confirmar
  (ver ADR-0008 y `docs/costos-mensuales.md`).

# Despliegue anterior en Azure Container Apps (histórico, ADR-0004)

Ver decisión completa en `docs/adr/0004-despliegue-api-azure-vs-laboratorio.md`.
Este procedimiento se conserva como alternativa con la misma imagen.

## Requisitos previos (una sola vez)

```bash
# Instalar Azure CLI si no la tienes, luego iniciar sesión con la cuenta
# de Azure for Students (sin tarjeta, verificación por correo @utb.edu.co).
az login

# Extensión de Container Apps y proveedores de recursos
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
```

## Alternativa A — servidor del laboratorio (sin cambios)

```bash
git clone https://github.com/ISCOUTB/AS_202620_AudioShare.git
cd AS_202620_AudioShare
docker compose up -d --build
curl -sS -o /dev/null -w 'http=%{http_code}\n' http://localhost:3000/health
```

## Alternativa B — Azure Container Apps

La imagen se construye en GitHub Actions y se publica en Docker Hub
(repositorio público); Azure solo la descarga. No se usa
`az containerapp up --source .` porque la suscripción Azure for Students
tiene bloqueado ACR Tasks (`TasksOperationsNotAllowed`). Tampoco se usó
GitHub Container Registry: la organización ISCOUTB deshabilita los
paquetes públicos y Azure recibió 403 al bajar un paquete interno.

**Región:** `canadacentral`. La política `sys.regionrestriction` de la
suscripción solo permite `chilecentral`, `mexicocentral`, `canadacentral`,
`belgiumcentral` y `spaincentral` (eastus y eastus2 fallan con
`RequestDisallowedByAzure`).

### 1. Publicar la imagen

El workflow `.github/workflows/publish-image.yml` construye el
`Dockerfile` y publica `vincexcard1916/audioshare-api:latest` en cada push
a `master` (secrets `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` del repositorio).

### 2. Crear el entorno y la Container App (primera vez)

```bash
az group create --name audioshare-rg --location canadacentral

az containerapp env create \
  --name audioshare-env \
  --resource-group audioshare-rg \
  --location canadacentral

az containerapp create \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --environment audioshare-env \
  --image docker.io/vincexcard1916/audioshare-api:latest \
  --target-port 3000 \
  --ingress external \
  --min-replicas 0 --max-replicas 3 \
  --env-vars PORT=3000 NODE_ENV=production DATABASE_FILE=data/audioshare.sqlite
```

### 3. Redesplegar (después de cada cambio)

```bash
az containerapp update \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --image docker.io/vincexcard1916/audioshare-api:latest
```

`minReplicas` en 0 mantiene el despliegue dentro del tramo gratis (ver
`docs/costos-mensuales.md`, punto de ruptura).

### 4. Verificación, con hora

```bash
URL=$(az containerapp show \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --query properties.configuration.ingress.fqdn -o tsv)

date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -sS -o /dev/null -w 'http=%{http_code} tiempo=%{time_total}s\n' "https://$URL/health"
curl -sS "https://$URL/metrics"
```

Verificación real del 2026-09-28T04:19:17Z:
`https://audioshare-api.icypond-27a6987e.canadacentral.azurecontainerapps.io/health`
→ `http=200 tiempo=1.909s`.

Métrica en el entorno desplegado, 2026-09-28T04:25:06Z (2026-09-27T23:25:06-05:00),
tras crear una sala: `rooms_created_total: 1`.

## Automatizar el despliegue desde CI (opcional, para más adelante)

`az containerapp update` también se puede correr desde `.github/workflows/`
con `azure/login@v2` usando credenciales federadas (OIDC, sin guardar
ningún secreto de larga duración) o un `AZURE_CREDENTIALS` de un
service principal. El workflow actual ya publica la imagen; solo
faltaría el paso de Azure. Se deja fuera de esta entrega porque
configurarlo bien (permisos del service principal dentro de una
suscripción de estudiante) es una tarea aparte que no debe bloquear la
evidencia de esta semana; el despliegue manual documentado arriba ya es
reproducible y verificable.

## Procedimiento de reversión

Como ambas alternativas corren la misma imagen Docker (`Dockerfile` sin
modificaciones entre A y B), revertir de Azure al servidor del
laboratorio —o viceversa— no requiere cambiar código:

1. Confirmar que la imagen del commit actual construye localmente:
   `docker build -t audioshare-api:rollback .`
2. Desplegar esa misma imagen en la alternativa de respaldo
   (`docker compose up -d --build` en el servidor del laboratorio, o
   `az containerapp update --image docker.io/vincexcard1916/audioshare-api:latest`
   en Azure).
3. Actualizar la URL publicada en el README y en la entrega de Moodle.
4. Tiempo estimado: menos de 10 minutos, limitado por el build de la
   imagen (la compilación nativa de `better-sqlite3` es lo más lento).

Costo de la reversión: se pierde el contenido de
`data/audioshare.sqlite` de la alternativa que se abandona, salvo que
se haya hecho backup del volumen — riesgo ya aceptado y documentado en
el ADR-0004.

## Errores frecuentes en esta suscripción

- `RequestDisallowedByAzure`: región no permitida. Usa una de
  `chilecentral`, `mexicocentral`, `canadacentral`, `belgiumcentral`
  o `spaincentral`.
- `MissingSubscriptionRegistration`: registra el proveedor con
  `az provider register --namespace <nombre> --wait`.
- `TasksOperationsNotAllowed`: ACR Tasks está bloqueado en Azure for
  Students. No uses `--source`; usa `--image`.
- `403 Forbidden` al bajar de ghcr.io: usa la imagen pública de Docker Hub.