# Análisis de dependencias

Elaborado el 2026-11-01 a partir de `package.json`, `package-lock.json`,
`pubspec.yaml`, `pubspec.lock`, el `Dockerfile` y los flujos de
`.github/workflows/`.

## Qué se hizo y qué falta ejecutar

| Parte | Cómo se hizo | Estado |
| --- | --- | --- |
| Inventario de paquetes y licencias de npm y de pub | Lectura de los archivos de bloqueo (`package-lock.json`, `pubspec.lock`) | Hecho |
| Revisión de la cadena de suministro (CI, Docker, rangos de versión) | Lectura de los archivos de configuración | Hecho |
| Consulta de un aviso concreto (`qs`) | Búsqueda en OSV y Tenable el 2026-11-01 | Hecho |
| `npm audit`, `npm outdated`, `flutter pub outdated` | **Se ejecutan en la máquina del equipo** con `scripts/analizar-dependencias.ps1`. El entorno donde se redactó este documento no tenía acceso a la red, así que no se pudo consultar el registro de avisos de npm. | Pendiente de ejecutar; ver «Resultado de la ejecución» |

Por eso este documento no afirma que «no hay vulnerabilidades»: afirma lo que
se pudo comprobar leyendo los archivos y deja las cifras de las herramientas
para el resumen que genera el script.

## Inventario

### Backend (npm)

- **240 paquetes** en `package-lock.json`: **70 de producción** (los que van en
  la imagen final) y **170 solo de desarrollo y pruebas**.
- **2 dependencias directas de producción:** `express` 4.22.3 y
  `better-sqlite3` 13.0.3.
- **11 dependencias directas de desarrollo:** `typescript` 5.9.3, `vitest`
  2.1.9, `supertest` 7.2.2, `tsx` 4.23.12, `ajv` 8.20.0, `js-yaml` 4.3.2 y
  los tipos `@types/*`.
- **Licencias de producción:** 67 MIT, 2 ISC y 1 BSD-3-Clause. No hay
  licencias copyleft. En desarrollo hay una licencia `Python-2.0`
  (`argparse`, usada por `js-yaml`), permisiva y que no se distribuye.
- **Paquetes con script de instalación:** `better-sqlite3` (compila un módulo
  nativo), `esbuild` (dos copias) y `fsevents` (solo macOS, opcional). Los
  tres ejecutan código durante `npm ci`.

### Cliente (pub)

- **61 paquetes** en `pubspec.lock`: 9 directos y 52 transitivos.
- **Directos de producción:** `file_picker` 8.3.7, `http` 1.6.0,
  `just_audio` 0.9.46, `just_audio_windows` 0.2.3, `path_provider` 2.1.5,
  `cupertino_icons` 1.0.9.
- **Directos de desarrollo:** `flutter_lints` 4.0.0 y `flutter_test` (SDK).
- Las licencias de pub **no** se revisaron: el archivo de bloqueo no las
  incluye. Se obtienen con `flutter pub deps` y la ficha de cada paquete en
  pub.dev.

## Hallazgos

Prioridad con la misma escala que en
[`amenazas-priorizadas.md`](./amenazas-priorizadas.md). `L` = lectura de
archivos; `V` = verificado contra una fuente externa en la fecha indicada.

| ID | Hallazgo | Prioridad | Evid. | Acción |
| --- | --- | --- | --- | --- |
| DEP-01 | **`qs` 6.16.1 queda fuera del rango afectado por CVE-2026-82417** (afecta a `>=2.2.5 <6.16.0` y se corrigió en 6.16.0). Es dependencia de producción: la trae `express` y `body-parser`. Un reporte público sobre Express 4.22.2 mencionaba además CVE-2026-82562 en `qs` 6.15.2; **ese segundo aviso no se verificó**. | Baja | V (2026-11-01) | Confirmar con `npm audit`; no hace falta actuar sobre el primer aviso. |
| DEP-02 | **El CI no revisa dependencias.** `.github/workflows/ci.yml` ejecuta `npm ci`, la compilación y las pruebas, pero ningún `npm audit`. `flutter.yml` tampoco revisa `pubspec`. Un aviso nuevo sobre `express` o `better-sqlite3` no se vería hasta mirar a mano. | Alta | L | Añadir un paso de `npm audit --omit=dev --audit-level=high` y activar Dependabot (ver más abajo). |
| DEP-03 | **Las acciones de GitHub se fijan por etiqueta**, no por SHA: `actions/checkout@v4`, `actions/setup-node@v4`, `subosito/flutter-action@v2`, `docker/login-action@v3`, `docker/build-push-action@v6`. Solo SonarCloud está fijada por SHA. Una etiqueta puede moverse. `publish-image.yml` usa secretos de Docker Hub, así que es el flujo más sensible. | Media | L | Fijar por SHA de commit y dejar que Dependabot proponga las actualizaciones. |
| DEP-04 | **La imagen se publica sin esperar al CI.** `publish-image.yml` se dispara con cada push a `master`, es independiente de `ci.yml`, y publica `vincexcard1916/audioshare-api:latest` sin análisis de la imagen. Una confirmación que rompa las pruebas igual produce una imagen publicada. | Media | L | Hacer que la publicación dependa del flujo de CI (`workflow_run` o `needs`) y etiquetar con el SHA además de `latest`. |
| DEP-05 | **Imágenes base sin digest.** `node:22-alpine` (flotante) y `ghcr.io/cirruslabs/flutter:3.35.7` (fijada por versión, no por digest). Los paquetes de Alpine (`python3`, `make`, `g++`) se instalan sin versión. | Baja | L | Aceptable para el prototipo; fijar por digest cuando se despliegue con usuarios reales. |
| DEP-06 | **Herramientas de compilación en la etapa final.** El `Dockerfile` instala `python3 make g++` en la etapa `runtime` para ejecutar `npm ci --omit=dev` y los elimina en la misma capa (`apk del`). Es correcto y deja la imagen final sin compiladores, pero esa etapa ejecuta el script de instalación de `better-sqlite3`. | Baja | L | Mantener; es el motivo para tener DEP-02 y fijar `package-lock.json`. |
| DEP-07 | **`vitest` 2.1.9 arrastra `vite` 5.4.21 y un `esbuild` 0.21.5 anidado**, más viejo que el `esbuild` 0.28.2 de `tsx`. Son dependencias de desarrollo y el CI usa `vitest run`, que no abre el servidor de desarrollo de Vite. Es probable que `npm audit` los marque; no se confirmó. | Baja | L | Revisar el resultado de `npm audit`. Si aparece, actualizar `vitest` a la versión vigente; no afecta a la imagen de producción. |
| DEP-08 | **`@types/node` 20.19.x con ejecución en Node 22** (`Dockerfile`, CI y el requisito `engines` de `better-sqlite3`). Los tipos no coinciden con el entorno real. | Baja | L | Subir `@types/node` a la rama 22. |
| DEP-09 | **Rangos `^` en `package.json`.** `npm ci` respeta el lock, pero un `npm install` o `npm update` puede subir cualquier paquete a una versión menor o parche nueva sin revisión. | Baja | L | Mantener `npm ci` en CI y Docker (ya es así); revisar los cambios del lock en cada PR. |
| DEP-10 | **Express en la rama 4.x.** Está en la línea 4.22.x, que sigue recibiendo parches, pero Express 5 es la rama vigente. No hay urgencia. | Baja | L | Registrar la migración a Express 5 como deuda técnica; confirmar el calendario de soporte de la rama 4 en el sitio de Express. |
| DEP-11 | **`just_audio_windows` 0.2.3 es un plugin de la comunidad.** Es la pieza que decodifica audio en Windows y parte de las corridas de EC-01 (receptor Windows). Su mantenimiento no se revisó. | Media | L | Revisar su ficha en pub.dev (última publicación, problemas abiertos) y decidir si se asume el riesgo. |

## Qué se agrega al repositorio para sostener esto

Archivo `.github/dependabot.yml` propuesto (no incluido en la entrega para no
generar propuestas automáticas sin que el equipo lo decida):

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule: { interval: weekly }
  - package-ecosystem: pub
    directory: /
    schedule: { interval: weekly }
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
  - package-ecosystem: docker
    directory: /
    schedule: { interval: weekly }
```

Paso propuesto para `.github/workflows/ci.yml`, después de `npm ci`:

```yaml
      - name: Auditoría de dependencias de producción
        run: npm audit --omit=dev --audit-level=high
```

Sin `continue-on-error`, un aviso alto rompe el CI. Si el equipo prefiere
empezar sin bloquear, se puede añadir `continue-on-error: true` y quitarlo
cuando el resultado esté limpio.

## Resultado de la ejecución

Ejecutado el 2026-11-01. Salida completa en
[`evidencia-dependencias-antes/`](./evidencia-dependencias-antes/) (estado
inicial) y [`evidencia-dependencias/`](./evidencia-dependencias/) (después de
`npm audit fix`). Tras la corrección, `npm run verify` compila y pasa las 44
pruebas.

| Herramienta | Antes | Después |
| --- | --- | --- |
| `npm audit --omit=dev` (producción) | 1 alto | **0** |
| `npm audit` (todo el árbol) | 9: 4 moderados, 3 altos, 2 críticos | 6: 3 moderados, 1 alto, 2 críticos |
| `npm outdated` | 9 paquetes desactualizados | — |
| `flutter pub get` | 25 paquetes con versión nueva fuera de las restricciones | — |

### Avisos y decisión

| Paquete | Severidad | Ámbito | Aviso | Decisión |
| --- | --- | --- | --- | --- |
| `body-parser` <1.20.9 | Alta | **Producción** (vía `express`) | DoS por bytes tras un cuerpo comprimido (GHSA-27r3-jxmh-p828) | **Corregido:** 1.20.8 → 1.20.9 con `npm audit fix`. Llega a la API pública cuando se redespliegue la imagen. |
| `fast-uri` 3.0.0–3.1.8 | Moderada | Desarrollo (vía `ajv`) | Cuatro avisos de manejo de URI | **Corregido:** 3.1.8 → 3.1.9. |
| `source-map-js` 1.0.0–1.2.1 | Alta | Desarrollo (vía `vite`) | DoS por desplazamientos de mapas de código | **Corregido:** 1.2.1 → 1.2.2. |
| `tinypool` ≤2.1.1 | Crítica | Desarrollo (vía `vitest`) | Contaminación de prototipo que lleva a RCE | **Aceptar con plan:** no va en la imagen y el CI solo ejecuta nuestras propias pruebas con `vitest run`; la corrección exige `vitest` 4.1.12, cambio mayor. |
| `vitest` ≤4.1.10, `@vitest/mocker` ≤4.1.11 | Moderada | Desarrollo | Lectura de archivos y registro de mocks sin autenticar | **Aceptar con plan:** igual que `tinypool`; no se usa el modo de servidor. |
| `vite` ≤6.4.3, `esbuild` ≤0.24.2 (copia anidada 0.21.5) | Moderada | Desarrollo | Cualquier sitio puede consultar el servidor de desarrollo | **Aceptar con plan:** el servidor de desarrollo de Vite no se abre. |

**Plan para los avisos aceptados:** migrar `vitest` a la rama 4.x en una tarea
aparte, con las pruebas pasando antes y después. Se revisa en la entrega
siguiente. La valoración de «no alcanzable» se hizo a partir del título de cada
aviso y del uso de `vitest` en este proyecto, no leyendo el detalle de cada uno.

**Lo que esto confirma:** el aviso de `body-parser` existía en producción y el
CI no lo detectaba (DEP-02). Con un paso `npm audit --omit=dev` habría fallado.

### Desactualizados

- `express` 4.22.3 frente a 5.3.0 (DEP-10), `typescript` 5.9.3 frente a 7.0.2 y
  `js-yaml` 4.3.2 frente a 5.5.0: saltos de versión mayor, sin urgencia.
- `@types/node` está en la rama 20 con Node 22 en ejecución (DEP-08).
- `supertest` y `tsx` tienen parches menores disponibles.
- Flutter: `file_picker` 8.3.7 frente a 13.3.0 y `just_audio` 0.9.46 frente a
  0.10.6. Revisar sus notas de cambios antes de subir.
