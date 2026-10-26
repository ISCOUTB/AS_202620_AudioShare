# AudioShare

## Descripción

AudioShare coordina una sala de reproducción de audio dentro de una red Wi-Fi local. La aplicación Flutter permite crear o unirse a una sala, consultar participantes y controlar el estado de reproducción.

## Objetivo

Conservar el corte vertical A-01: crear sala, registrar receptores, iniciar o pausar reproducción, generar `startAt`, distribuir eventos y consultar el estado persistido.

## Funcionalidades

- Crear una sala como emisor.
- Unirse a una sala como receptor mediante su código.
- Mostrar participantes y receptores conectados.
- Ejecutar play/pause desde el emisor.
- Seleccionar y subir un MP3 por sala; los receptores descargan esa misma pista.
- Mostrar `startAt`, posición y estado de sincronización.
- Reproducir la pista en receptores con `just_audio`, incluyendo búsqueda por posición.

## Arquitectura

La solución conserva el monolito modular del backend y añade Flutter como cliente:

```text
Flutter (UI -> ViewModel -> Repository -> ApiClient)
                         |
              HTTP/JSON y stream NDJSON
                         v
Node/Express (Session, Sync, Audio) -> SQLite
```

SQLite continúa siendo responsabilidad exclusiva del backend. La decisión está en [ADR-0001](docs/adr/0001-usar-monolito-modular.md) y su relación con Flutter en [ADR-0003](docs/adr/0003-transicion-a-flutter.md).

## Tecnologías

- Flutter/Dart, Material 3, null safety.
- Node.js/Express para la API y la comunicación entre dispositivos.
- SQLite para salas, participantes y estado.

## Estructura del proyecto

```text
lib/                         cliente Flutter
  app/                       aplicación y tema
  core/network/              cliente HTTP y errores
  features/session/          modelos, repositorio, ViewModel y páginas
  features/audio/            AudioService y mock
  features/sync/             SyncService y snapshot temporal
src/                         backend modular conservado
test/                        pruebas Flutter/Dart
tests/                       pruebas del backend
docs/                        arquitectura y trazabilidad
```

## Requisitos

- Flutter estable con soporte Android o Web.
- Node.js 22+ para el backend (misma versión que usa `.github/workflows/ci.yml`).

En GitHub Codespaces, el repositorio incluye `.devcontainer/devcontainer.json`. Al crear o reconstruir el Codespace se instalan automáticamente Flutter, Dart, Google Chrome y las extensiones de VS Code necesarias.

## Instalación

```bash
flutter pub get
npm ci
```

## Ejecución

Compila Flutter Web y arranca el backend; Express sirve ambos bajo el mismo
origen en `http://localhost:3000`:

```bash
flutter build web
npm run dev
```

Para desarrollo Flutter con recarga en caliente, mantén `npm run dev` en una
terminal y arranca Flutter en otra. Configura explícitamente la URL de la API;
un servidor web separado no puede deducir de forma fiable dónde está el backend:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=AUDIOSHARE_API_URL=http://localhost:3000
```

En Codespaces, abre la app preferiblemente desde el puerto `3000`, que sirve
Flutter y API en el mismo origen. Si necesitas hot reload en el puerto `8080`,
usa una segunda terminal y pasa explícitamente el host del backend:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define="AUDIOSHARE_API_URL=https://${CODESPACE_NAME}-3000.app.github.dev"
```

El backend permite el origen Flutter del Codespace actual y los orígenes
localhost de desarrollo; en producción, CORS solo permite el dominio público.
En un dispositivo físico, configura un backend HTTPS público o la IP LAN del
servidor desde «Opciones avanzadas». `localhost` en el teléfono no representa
el computador.

## Tests

```bash
flutter analyze
flutter test
npm test
```

## Build

```bash
flutter build web
```

### GitHub Codespaces

Después de crear un Codespace nuevo, espera a que termine `postCreateCommand` y verifica el entorno:

```bash
flutter --version
dart --version
flutter pub get
flutter analyze
flutter test
flutter build web
```

La ruta recomendada en Codespaces es abrir el puerto `3000`, porque mantiene la interfaz Flutter y la API en el mismo origen. El puerto `8080` queda disponible para el servidor de desarrollo con recarga en caliente. `flutter run -d chrome` requiere una sesión gráfica; Google Chrome queda instalado para pruebas headless y el build Web.

## Arquitectura y documentación

- [arc42](docs/arc42/)
- [ADRs](docs/adr/)
- [Diagramas C4](docs/c4/)
- [Trazabilidad](docs/aspectos.md)
- [Escenarios de calidad](docs/escenarios_calidad.md)
- [Modos de fallo y mitigaciones](docs/modos-de-fallo.md)
- [Idempotencia y análisis de saga](docs/idempotencia-y-saga.md)
- [ADR-0009 — No extraer módulos como servicios](docs/adr/0009-no-extraer-modulos-como-servicios.md)
- [ADR-0010 — Distribuir una pista MP3 por sala mediante HTTP](docs/adr/0010-transporte-de-pista-por-http.md)

## Estado actual

**Implementado:** cliente Flutter Material 3, creación y unión de salas, consulta de estado, participantes, play/pause, repositorio HTTP, ViewModel, persistencia SQLite en backend y pruebas automatizadas.

**Audio reproducible implementado:** al crear sala, el emisor selecciona un MP3 de hasta 50 MiB. Flutter lo sube como `audio/mpeg` a `POST /rooms/:roomId/track`; Audio lo guarda en `data/tracks/` dentro del volumen persistente. Cada receptor descarga la misma pista con `GET /rooms/:roomId/track` (incluye soporte Range) y `just_audio` la busca y reproduce localmente. El receptor calibra su reloj, usa `startAt`, pausa/reanuda desde la posición guardada y, si se une durante la reproducción, calcula la posición transcurrida. El test A-01 comprueba identidad byte a byte en upload/download; las pruebas Flutter verifican la petición binaria y el flujo del receptor.

**Límites verificados:** `audio.chunk` sigue siendo un evento JSON con payload de texto demostrativo; no transporta ni controla el MP3. El audio viaja por el endpoint binario HTTP separado. Esta entrega comparte una pista completa, no captura ni transmite micrófono en vivo. La reproducción en el dispositivo usa `just_audio`, pero la salida física y el desfase entre dispositivos aún requieren validación con equipos reales; EC-01/EC-02 no se consideran demostrados físicamente.

Flutter Web usa el mismo origen desde el que se sirve la app; el contenedor
Express entrega tanto el frontend como la API. Los clientes nativos usan
`https://audioshare.iscoutb.dev` por defecto. Un override
`AUDIOSHARE_API_URL` se valida y nunca se reemplaza silenciosamente por otro
servidor; una compilación release rechaza localhost, HTTP y hosts temporales.

## Evolución del proyecto

AudioShare inició su desarrollo utilizando un cliente web. Durante la
evolución del proyecto se tomó la decisión de realizar una transición
hacia una aplicación móvil desarrollada con Flutter.

El objetivo de esta transición es adaptar el cliente a dispositivos
móviles manteniendo las responsabilidades principales del backend.

## CI

`.github/workflows/flutter.yml` ejecuta `flutter pub get`, `flutter analyze`, `flutter test` y `flutter build web`. `.github/workflows/ci.yml` conserva la compilación y las pruebas del backend. Dokploy construye el Dockerfile del repositorio desde `docker-compose.yml`; `publish-image.yml` publica además una imagen en Docker Hub que Dokploy no consume.

## Despliegue

El despliegue usa Dokploy y Docker Compose. El Dockerfile compila Flutter Web y Express sirve frontend, API y `/health` desde el mismo origen. Una comprobación directa del 2026-10-26 encontró que `https://audioshare.iscoutb.dev/` aún entrega el cliente legado y `GET /rooms` responde 404; por tanto, se requiere un redespliegue desde la revisión actual antes de declarar operativa esta configuración. El volumen persistente contiene SQLite y las pistas MP3 por sala.

## Aplicación

**URL pública:**

https://audioshare.iscoutb.dev

La URL permite acceder directamente a la aplicación AudioShare desplegada.

## Infraestructura

El despliegue utiliza:

-Docker
-Docker Compose.
-Dokploy.
-Node.js / Express.
-Flutter Web (compilado en una etapa del `Dockerfile` y servido por Express).
-SQLite.

Los archivos principales relacionados con el despliegue son:

Dockerfile
docker-compose.yml
.env.example
.github/workflows/

## Docker Compose

El entorno puede recrearse utilizando:

docker compose up -d --build

## Despliegue mediante Dokploy

El despliegue productivo utiliza Dokploy como plataforma de administración de los contenedores.

El proyecto se configura a partir del archivo:

docker-compose.yml

Dokploy utiliza esta configuración para construir y ejecutar los servicios definidos por AudioShare.

## Acceso a la aplicación

La aplicación desplegada puede utilizarse desde:

https://audioshare.iscoutb.dev

El despliegue permite demostrar el funcionamiento del corte vertical A-01 sobre el entorno publicado.

## Limitaciones conocidas

-La captura de micrófono y transmisión en vivo todavía están pendientes; el alcance implementado es distribuir una pista MP3 completa por sala.
-La salida física, la sincronización EC-01/EC-02 y la latencia deben verificarse con dispositivos reales; los tests de ViewModel no sustituyen esa medición.
-La persistencia SQLite depende del almacenamiento configurado en el entorno de despliegue.
-El stream NDJSON se reconecta automáticamente; la restauración de sesión y descarga tras una desconexión todavía requiere validación.
-Las mediciones definitivas de EC-01 y EC-02 todavía deben validarse en un escenario real con múltiples dispositivos.

## Corte vertical A-01

El corte vertical principal del proyecto corresponde a la sincronización de reproducción de audio.

El flujo contempla:

1. El emisor crea una sala.
2. Los receptores se unen mediante el código de la sala.
3. El backend registra los participantes.
4. El emisor inicia o pausa la reproducción.
5. El backend genera y distribuye el estado de reproducción.
6. Los receptores consultan el estado y la posición temporal.
7. El sistema utiliza una referencia temporal común para mantener la sincronización.

## Aspectos de calidad relacionados

**EC-01:** diferencia de sincronización objetivo ≤ 100 ms.

**EC-02:** variación de latencia objetivo ≤ 200 ms.

**R-01:** utilización de herramientas sin costo obligatorio.

**R-02:** comunicación de los dispositivos dentro de la misma red Wi-Fi.

## Licencia

Proyecto académico desarrollado para la asignatura correspondiente de Ingeniería de Sistemas.

## About

Plataforma para transmitir audio en tiempo real desde un dispositivo a múltiples dispositivos conectados.
