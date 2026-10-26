# Estimación de costo mensual — API de AudioShare

Sigue el apartado "Cómo estimar el costo mensual" de la Guía de
despliegue y costos. Los cuatro números salen del escenario de calidad
EC-01/EC-04 (`docs/escenarios_calidad.md`) y de un supuesto de uso
razonable para un prototipo académico en demo, no en producción.

## Supuestos de volumen

| Variable | Supuesto | De dónde sale |
|---|---|---|
| Salas creadas / mes | 500 | ~4 equipos de prueba × ~4 sesiones/día × ~30 días, redondeado a la baja |
| Receptores por sala | 3 (promedio) | Consistente con las pruebas de `tests/a01.test.ts` (2 receptores) más margen |
| Eventos `play`/`pause` por sala | 6 | Uso típico de una demo corta |
| Tamaño de datos almacenados | SQLite < 10 MB más archivos MP3 | Cada sala puede almacenar un MP3 de hasta 50 MiB; el total depende de salas y retención. Las pistas comparten el volumen persistente con SQLite. |
| Tráfico de salida estimado | NDJSON: ~500 salas × 3 receptores × (6 eventos × ~200 bytes) ≈ **1.8 MB/mes**, más descargas MP3 | La estimación NDJSON excluye la pista; el tráfico MP3 depende de duración, bitrate, receptores y repeticiones. |
| Horas de ejecución | 720 h/mes si el proceso está siempre activo (servidor del laboratorio); variable en Render Free por el sleep tras inactividad | — |

## Costo por alternativa

### Alternativa A — Servidor del laboratorio

Costo: **$0**, sin punto de ruptura conocido — es infraestructura ya
asignada al curso, no facturación por uso. El límite real no es de
dinero sino de recursos: cuánto disco y CPU asigna el laboratorio por
equipo.

### Alternativa B — Azure Container Apps (Azure for Students)

Concesión gratuita mensual verificada el 2026-09-27 en
azure.microsoft.com/pricing/details/container-apps: 180.000
vCPU-segundos, 360.000 GiB-segundos y 2.000.000 de solicitudes **por
mes, de forma perpetua** (no es el crédito de $100 de estudiante, es
una condición del servicio que sigue aplicando después de que el
crédito se agote o expire).

Con 500 salas/mes × 3 receptores × 6 eventos, las solicitudes HTTP
mensuales están en el orden de unos pocos miles — muy por debajo de
los 2 millones gratis. El campo que sí hay que vigilar es
vCPU-segundos, y depende de una decisión de configuración, no solo de
volumen:

| Configuración | vCPU-segundos/mes estimados | ¿Dentro del tramo gratis? |
|---|---|---|
| `minReplicas: 0` (escala a cero entre usos) | Solo mientras hay tráfico real: con demos cortas, del orden de unos pocos miles de vCPU-segundos/mes | Sí, con margen amplio |
| `minReplicas: 1` (siempre despierto, 0.5 vCPU) | 0.5 × 2.592.000 s ≈ 1.296.000 vCPU-s/mes | **No** — rompe el tramo gratis por ~7× |

**Punto de ruptura real:** no es el volumen de uso del sistema, es la
decisión de mantener una réplica siempre activa. `minReplicas: 0` es
la opción que se queda gratis; el costo que se asume a cambio es el
mismo riesgo de arranque en frío que tenía Render con su "sleep" —
compite con el objetivo de EC-04 (receptor nuevo en ≤3 s) si la
primera petición llega justo después de un período sin tráfico. Se
documenta como riesgo aceptado, igual que se hizo con Render.

El endpoint actual distribuye una pista MP3 completa, por lo que el
tráfico de salida crece aproximadamente con el tamaño del archivo por
cada receptor que lo descarga. La captura/streaming en vivo sigue fuera
de alcance y cualquier estimación de consumo debe añadir las pistas MP3.

## Costo que no es dinero

- Minutos de CI: el workflow `ci.yml` corre en cada push; en un
  repositorio público de GitHub Actions no consume cuota (ver Guía de
  despliegue y costos, "Tu repositorio es público").
- Tiempo de despliegue manual: con `docker compose up -d --build` o el
  deploy automático de Render desde `main`, el redespliegue es de
  minutos, no de horas.
- Personas que saben redesplegar: hoy documentado solo en este
  archivo y en el ADR-0004; el equipo debe verificar en la sustentación
  que más de una persona puede ejecutar el procedimiento sin ayuda.

## Alternativa C — Dokploy (despliegue actual, ADR-0008)

**Costo no cuantificado.** Lo que se sabe del panel (capturas del
2026-10-13): el servidor de Dokploy tiene 11,67 GiB de RAM y 76,45 GB de
disco, y a las 06:16 UTC la máquina completa usaba 2,47 % de CPU, 2,37 GiB
de memoria y 21,75 GB de disco. Ese es el uso de todo lo que corre allí;
el monitoreo del propio servicio de AudioShare no muestra datos, así que
su consumo no está medido.
