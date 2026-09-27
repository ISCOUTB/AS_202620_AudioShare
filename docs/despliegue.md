# Despliegue de la API en Azure Container Apps

Ver decisión completa en `docs/adr/0004-despliegue-api-azure-vs-laboratorio.md`.

## Requisitos previos (una sola vez)

```bash
# Instalar Azure CLI si no la tienes, luego iniciar sesión con la cuenta
# de Azure for Students (sin tarjeta, verificación por correo @utb.edu.co).
az login

# Extensión de Container Apps
az extension add --name containerapp --upgrade
```

## Alternativa A — servidor del laboratorio (sin cambios)

```bash
git clone https://github.com/ISCOUTB/AS_202620_AudioShare.git
cd AS_202620_AudioShare
docker compose up -d --build
curl -sS -o /dev/null -w 'http=%{http_code}\n' http://localhost:3000/health
```

## Alternativa B — Azure Container Apps

`az containerapp up` construye la imagen a partir del `Dockerfile` del
repositorio (usa un build efímero en la nube, no necesitas un registro
de contenedores propio) y publica una URL pública HTTPS en un solo
comando:

```bash
cd AS_202620_AudioShare

az containerapp up \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --location eastus \
  --environment audioshare-env \
  --source . \
  --target-port 3000 \
  --ingress external \
  --env-vars PORT=3000 NODE_ENV=production DATABASE_FILE=data/audioshare.sqlite

# minReplicas en 0: es lo que mantiene el despliegue dentro del tramo
# gratis (ver docs/costos-mensuales.md, punto de ruptura). Ajustar solo
# si se decide asumir el costo de tenerlo siempre despierto.
az containerapp update \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --min-replicas 0 \
  --max-replicas 3
```

Verificación tras cada despliegue, con hora (para la evidencia que pide
la ficha de la semana 8):

```bash
URL=$(az containerapp show \
  --name audioshare-api \
  --resource-group audioshare-rg \
  --query properties.configuration.ingress.fqdn -o tsv)

date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -sS -o /dev/null -w 'http=%{http_code} tiempo=%{time_total}s\n' "https://$URL/health"
```

## Automatizar el despliegue desde CI (opcional, para más adelante)

`az containerapp up` también se puede correr desde `.github/workflows/`
con `azure/login@v2` usando credenciales federadas (OIDC, sin guardar
ningún secreto de larga duración) o un `AZURE_CREDENTIALS` de un
service principal. Se deja fuera de esta entrega porque configurarlo
bien (permisos del service principal dentro de una suscripción de
estudiante) es una tarea aparte que no debe bloquear la evidencia de
esta semana; el despliegue manual documentado arriba ya es reproducible
y verificable.

## Procedimiento de reversión

Como ambas alternativas corren la misma imagen Docker (`Dockerfile` sin
modificaciones entre A y B), revertir de Azure al servidor del
laboratorio —o viceversa— no requiere cambiar código:

1. Confirmar que la imagen del commit actual construye localmente:
   `docker build -t audioshare-api:rollback .`
2. Desplegar esa misma imagen en la alternativa de respaldo
   (`docker compose up -d --build` en el servidor del laboratorio, o
   `az containerapp up` con `--source .` apuntando al mismo commit).
3. Actualizar la URL publicada en el README y en la entrega de Moodle.
4. Tiempo estimado: menos de 10 minutos, limitado por el build de la
   imagen (la compilación nativa de `better-sqlite3` es lo más lento).

Costo de la reversión: se pierde el contenido de
`data/audioshare.sqlite` de la alternativa que se abandona, salvo que
se haya hecho backup del volumen — riesgo ya aceptado y documentado en
el ADR-0004.

## Si algo del comando `az containerapp up` falla

- `ResourceGroupNotFound`: créalo primero con
  `az group create --name audioshare-rg --location eastus`.
- Error de cuota o de permisos en la suscripción de estudiante: revisa
  en el portal de Azure que la suscripción "Azure for Students" esté
  activa (no "Azure for Students Starter", que no incluye Container
  Apps) y que la región `eastus` tenga cuota disponible; si no, prueba
  con `eastus2` o `westus2`.
