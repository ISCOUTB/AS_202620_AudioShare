// Descarga de la pista a un archivo local. En plataformas con `dart:io` baja el
// archivo completo; en Web no hay sistema de archivos y devuelve null (se usa
// la URL directamente).
export 'track_downloader_stub.dart'
    if (dart.library.io) 'track_downloader_io.dart';
