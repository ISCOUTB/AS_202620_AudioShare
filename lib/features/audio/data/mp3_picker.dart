import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Un MP3 elegido por el usuario.
class PickedMp3 {
  const PickedMp3({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// El archivo no se pudo usar; [message] se muestra tal cual al usuario.
class Mp3PickException implements Exception {
  const Mp3PickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Límite que acepta el servidor para una pista.
const maxMp3Bytes = 50 * 1024 * 1024;

/// Abre el selector de archivos. Devuelve null si el usuario cancela y lanza
/// [Mp3PickException] si el archivo no sirve.
Future<PickedMp3?> pickMp3() async {
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
  } catch (exception) {
    throw Mp3PickException('No se pudo seleccionar el MP3: $exception');
  }
  if (result == null) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const Mp3PickException('No se pudo leer el archivo seleccionado.');
  }
  if (bytes.length > maxMp3Bytes) {
    throw const Mp3PickException('El MP3 no puede superar 50 MB.');
  }
  return PickedMp3(bytes: bytes, name: file.name);
}
