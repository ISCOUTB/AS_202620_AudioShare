# Entorno de desarrollo AudioShare

El proyecto detecta GitHub Codespaces mediante `.devcontainer/devcontainer.json`.
Al crear o reconstruir el Codespace, el Dockerfile instala automáticamente Flutter, Dart y Google Chrome para Flutter Web.

Versiones y comandos disponibles dentro del contenedor:

```bash
flutter --version
dart --version
flutter pub get
flutter analyze
flutter test
flutter build web
```

La aplicación Web puede ejecutarse con `flutter run -d web-server --web-port 8080` y abrir el puerto reenviado. `flutter run -d chrome` requiere una sesión gráfica local; en Codespaces sin GUI se usa `web-server` o pruebas headless con Chromium.
