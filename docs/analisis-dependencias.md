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
| `npm audit`, `npm outdated`, `flutter pub outdated` | **Se ejecutan en la máquina del equipo** con `scripts/analizar-dependencias.ps1`. | ver «Resultado de la ejecución» |


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
| DEP-02 | **El CI no revisaba dependencias.** `.github/workflows/ci.yml` ejecutaba `npm ci`, la compilación y las pruebas, pero ningún `npm audit`, y un aviso nuevo sobre `express` o `better-sqlite3` no se habría visto (el de `body-parser` existía en producción sin que nada avisara). `flutter.yml` tampoco revisa `pubspec`. | Alta | L | **Corregido en la semana 14:** `ci.yml` ejecuta `npm audit --omit=dev --audit-level=high` después de `npm ci`. Queda activar Dependabot (ver más abajo) y revisar `pubspec` a mano con `flutter pub outdated`. |
| DEP-03 | **Las acciones de GitHub se fijan por etiqueta**, no por SHA: `actions/checkout@v4`, `actions/setup-node@v4`, `subosito/flutter-action@v2`, `docker/login-action@v3`, `docker/build-push-action@v6`. Solo SonarCloud está fijada por SHA. Una etiqueta puede moverse. `publish-image.yml` usa secretos de Docker Hub, así que es el flujo más sensible. | Media | L | Fijar por SHA de commit y dejar que Dependabot proponga las actualizaciones. |
| DEP-04 | **La imagen se publica sin esperar al CI.** `publish-image.yml` se dispara con cada push a `master`, es independiente de `ci.yml`, y publica `vincexcard1916/audioshare-api:latest` sin análisis de la imagen. Una confirmación que rompa las pruebas igual produce una imagen publicada. | Media | L | Hacer que la publicación dependa del flujo de CI (`workflow_run` o `needs`) y etiquetar con el SHA además de `latest`. |
| DEP-05 | **Imágenes base sin digest.** `node:22-alpine` (flotante) y `ghcr.io/cirruslabs/flutter:3.35.7` (fijada por versión, no por digest). Los paquetes de Alpine (`python3`, `make`, `g++`) se instalan sin versión. | Baja | L | Aceptable para el prototipo; fijar por digest cuando se despliegue con usuarios reales. |
| DEP-06 | **Herramientas de compilación en la etapa final.** El `Dockerfile` instala `python3 make g++` en la etapa `runtime` para ejecutar `npm ci --omit=dev` y los elimina en la misma capa (`apk del`). Es correcto y deja la imagen final sin compiladores, pero esa etapa ejecuta el script de instalación de `better-sqlite3`. | Baja | L | Mantener; es el motivo para tener DEP-02 y fijar `package-lock.json`. |
| DEP-07 | **`vitest` 2.1.9 arrastra `vite` 5.4.21, un `esbuild` 0.21.5 anidado y `tinypool`.** `npm audit` los marcó (seis avisos de desarrollo, dos críticos). Son dependencias de desarrollo: no llegan a la imagen. Análisis completo por aviso en «Resultado de la ejecución». | Media | V (2026-11-01 y 2026-11-08) | Aceptado con análisis y plan: migrar `vitest` a 4.1.12, que según `npm audit` los resuelve. |
| DEP-08 | **`@types/node` 20.19.x con ejecución en Node 22** (`Dockerfile`, CI y el requisito `engines` de `better-sqlite3`). Los tipos no coinciden con el entorno real. | Baja | L | Subir `@types/node` a la rama 22. |
| DEP-09 | **Rangos `^` en `package.json`.** `npm ci` respeta el lock, pero un `npm install` o `npm update` puede subir cualquier paquete a una versión menor o parche nueva sin revisión. | Baja | L | Mantener `npm ci` en CI y Docker (ya es así); revisar los cambios del lock en cada PR. |
| DEP-10 | **Express en la rama 4.x.** Está en la línea 4.22.x, que sigue recibiendo parches, pero Express 5 es la rama vigente. No hay urgencia. | Baja | L | Registrar la migración a Express 5 como deuda técnica; confirmar el calendario de soporte de la rama 4 en el sitio de Express. |
| DEP-11 | **`just_audio_windows` 0.2.3 es un plugin de la comunidad.** Es la pieza que decodifica audio en Windows y parte de las corridas de EC-01 (receptor Windows). Su mantenimiento no se revisó. | Media | L | Revisar su ficha en pub.dev (última publicación, problemas abiertos) y decidir si se asume el riesgo. |
| DEP-12 | **La acción de SonarCloud tiene avisos de seguridad.** `ci.yml` usa `SonarSource/sonarqube-scan-action` fijada por el SHA `689fb39b…` (el SHA no se pudo asociar a una versión sin acceso a la red). Hay dos avisos de inyección de comandos por argumentos en las versiones ≥ 4.0.0 y < 6.0.0: CVE-2025-58178 (corregido en 5.3.1) y CVE-2025-59844 (corregido en 6.0.0). El vector es pasar valores controlables por terceros en `args`; `ci.yml` no pasa `args`, por lo que la exposición práctica es baja. | Media | V (2026-11-08) | **Actualizar** a la versión 6.0.0 fijada por SHA (comando en la entrega de la semana 14). |

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
| `body-parser` <1.20.9 | Alta | **Producción** (vía `express`) | DoS por bytes tras un cuerpo comprimido (GHSA-27r3-jxmh-p828) | **Corregido:** 1.20.8 → 1.20.9 con `npm audit fix`. Verificado en producción el 2026-11-01: `npm ls body-parser` dentro del contenedor de Dokploy muestra 1.20.9. |
| `fast-uri` 3.0.0–3.1.8 | Moderada | Desarrollo (vía `ajv`) | Cuatro avisos de manejo de URI | **Corregido:** 3.1.8 → 3.1.9. |
| `source-map-js` 1.0.0–1.2.1 | Alta | Desarrollo (vía `vite`) | DoS por desplazamientos de mapas de código | **Corregido:** 1.2.1 → 1.2.2. |

Los seis avisos restantes están en la cadena de `vitest` y son de desarrollo
(`tinypool`, `vitest`, `@vitest/mocker`, `vite`, `vite-node` y la copia anidada
de `esbuild`). Se leyó el texto de cada aviso en OSV y en bases de avisos de
terceros (consultadas el 2026-11-08), no solo su título.

### Análisis completo de los avisos de desarrollo

| Aviso | Qué afecta | Precondición del ataque | ¿Se cumple aquí? | Corrección |
| --- | --- | --- | --- | --- |
| **`tinypool` ≤2.1.1** (GHSA-5gmw-xhrv-c9v3, crítica, CVSS 4.0 de 9,5) | Las opciones `execArgv` y `env` del worker se leen de un objeto normal; con `Object.prototype` contaminado cada worker carga código del atacante | El atacante ya debe poder **contaminar `Object.prototype`** en el proceso que usa `tinypool` | No. El proceso de `vitest` ejecuta solo nuestras pruebas y no procesa entradas de terceros; no hay un primitivo de contaminación a la vista. Quien pudiera ejecutar código en ese proceso (por ejemplo, con una PR) ya lo ejecuta sin necesitar este aviso | `tinypool` 2.1.1 |
| **`tinypool` ≤2.1.1** (GHSA-85c8-ppgw-ccpr) | La opción `filename` de `pool.run(task, options)` | Igual que el anterior, y además que la aplicación pase su **propio** objeto de opciones a `pool.run()` | No por la misma razón; no se revisó si `vitest` pasa opciones propias | `tinypool` 2.1.2 |
| **`@vitest/mocker` ≤4.1.11 y `vitest` ≤4.1.10** (GHSA-82fw-gwwq-j7x9, moderada) | Lectura de archivos fuera de la raíz por un mock de tipo redirección, registrado en el WebSocket **sin autenticar** del servidor de desarrollo de Vite | Un servidor de desarrollo de Vite con el interceptor activo y accesible por el atacante. El modo navegador de `vitest` usa un canal con token y no es alcanzable de forma remota por defecto | No. `vitest.config.ts` usa `environment: "node"` y `pool: "forks"`, sin `browser`; los scripts son `vitest run`, sin `--ui` ni `api` | `@vitest/mocker` 4.1.11 y, por la omisión en Windows (CVE-2026-112950), **4.1.12** |
| **`@vitest/mocker` ≤4.1.11** (GHSA-qxg6-89mg-rqv8, moderada) | Inyección de código por el registro manual de mocks, en el mismo manejador | Un cliente WebSocket **con acceso al puerto** del servidor de desarrollo | No, por lo mismo: no se abre ese servidor | 4.1.12 (y 5.0.3) |
| **`esbuild` ≤0.24.2** (GHSA-67mh-4wv8-2f99, moderada), copia anidada 0.21.5 | Con la función `serve` de esbuild, cualquier sitio web puede leer el código fuente por la política CORS abierta | Usar la función `serve` de esbuild y visitar una página maliciosa | No. Ningún script usa `esbuild --serve`; `tsx` usa su propia copia (0.28.2), que no está afectada | 0.25.0 |
| **`vite` ≤6.4.3 y `vite-node`** | Sin aviso propio: `npm audit` los marca porque dependen de la copia vulnerable de `esbuild` | Ver `esbuild` | No | Se resuelven al actualizar `vitest` |

**Decisión.** Aceptar los seis con esta justificación, no solo con el título del
aviso, y salir de ellos migrando `vitest` de 2.1.9 a 4.1.12, que según `npm audit`
resuelve toda la cadena (cambio de versión mayor). Plan de migración:

1. `npm install -D vitest@4.1.12` y `npm run verify` (44 pruebas).
2. Si pasan, se confirma con `npm audit` que el árbol completo queda en cero y
   se actualiza esta sección.
3. Si no pasan, se anotan los cambios necesarios y se mantiene la aceptación.

**Cuándo se revisa esta decisión:** si alguien habilita `browser`, `--ui` o `api`
en `vitest`, si se usa el servidor de desarrollo de Vite o `esbuild --serve`, o si
el proceso de pruebas empieza a procesar entradas que no controla el equipo.

**Lo que esto confirma:** el aviso de `body-parser` existía en producción y el
CI no lo detectaba (DEP-02). Con un paso `npm audit --omit=dev` habría fallado.

### Desactualizados

- `express` 4.22.3 frente a 5.3.0 (DEP-10), `typescript` 5.9.3 frente a 7.0.2 y
  `js-yaml` 4.3.2 frente a 5.5.0: saltos de versión mayor, sin urgencia.
- `@types/node` está en la rama 20 con Node 22 en ejecución (DEP-08).
- `supertest` y `tsx` tienen parches menores disponibles.
- Flutter: `file_picker` 8.3.7 frente a 13.3.0 y `just_audio` 0.9.46 frente a
  0.10.6. Revisar sus notas de cambios antes de subir.
