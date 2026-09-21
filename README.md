# AudioShare

## Descripción

AudioShare coordina una sala de reproducción de audio dentro de una red Wi-Fi local. La aplicación Flutter permite crear o unirse a una sala, consultar participantes y controlar el estado de reproducción.

## Objetivo

Conservar el corte vertical A-01: crear sala, registrar receptores, iniciar o pausar reproducción, generar `startAt`, distribuir eventos y consultar el estado persistido.

<<<<<<< HEAD
Requisitos: Node.js 22+.
=======
## Funcionalidades
>>>>>>> be5a6af (Migrar AudioShare a Flutter)

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

SQLite continúa siendo responsabilidad exclusiva del backend. La decisión está en [ADR-0001](docs/adr/0001-usar-monolito-modular.md) y su relación con Flutter en [ADR-0002](docs/adr/0002-cliente-flutter-backend-modular.md).

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
- Node.js 20+ para el backend.

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

## CI

`.github/workflows/flutter.yml` ejecuta `flutter pub get`, `flutter analyze`, `flutter test` y `flutter build web`. `.github/workflows/ci.yml` conserva la compilación y las pruebas del backend.
