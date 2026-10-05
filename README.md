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
- Mostrar `startAt`, posición y estado de sincronización.
- Encapsular volumen individual y audio tras servicios reemplazables.

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

Inicia el backend y la aplicación Flutter Web en `http://localhost:3000`:

```bash
npm run dev
```

Cuando exista `build/web`, el backend sirve automáticamente esa aplicación Flutter en el mismo puerto. Para reconstruirla tras cambios:

```bash
flutter build web
```

Para desarrollo Flutter con recarga en caliente, usa otra terminal:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

En Android, configura el backend con una dirección accesible desde el dispositivo. El cliente usa `10.0.2.2:3000` por defecto en el emulador Android y la URL de la página en Web.

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

## Estado actual

**Implementado:** cliente Flutter Material 3, creación y unión de salas, consulta de estado, participantes, play/pause, repositorio HTTP, ViewModel, persistencia SQLite en backend y pruebas automatizadas.

**Simulado:** `AudioService` usa `MockAudioService`; el backend genera `audio.chunk` demostrativos y el stream NDJSON está disponible para integración.

**Pendiente:** captura, codificación, transmisión y reproducción física; consumo Flutter del stream NDJSON; reconexión automática; mediciones que demuestren EC-01 (100 ms) y EC-02 (200 ms); control de acceso.

## Evolución del proyecto

AudioShare inició su desarrollo utilizando un cliente web. Durante la
evolución del proyecto se tomó la decisión de realizar una transición
hacia una aplicación móvil desarrollada con Flutter.

El objetivo de esta transición es adaptar el cliente a dispositivos
móviles manteniendo las responsabilidades principales del backend.

## CI

`.github/workflows/flutter.yml` ejecuta `flutter pub get`, `flutter analyze`, `flutter test` y `flutter build web`. `.github/workflows/ci.yml` conserva la compilación y las pruebas del backend. `.github/workflows/publish-image.yml` construye la imagen Docker de la API y la publica en Docker Hub en cada push a `master`.

## Despliegue

La aplicación se encuentra desplegada públicamente mediante Dokploy, utilizando Docker Compose.

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
-Flutter Web.
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

-La captura, codificación, transmisión y reproducción física del audio todavía se encuentran fuera del alcance de la implementación actual.
-AudioService utiliza actualmente un servicio simulado.
-La transmisión real de audio entre dispositivos todavía se encuentra pendiente.
-La persistencia SQLite depende del almacenamiento configurado en el entorno de despliegue.
-La reconexión automática todavía se encuentra pendiente.
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
