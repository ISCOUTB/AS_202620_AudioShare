import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _headersTimeout = Duration(seconds: 20);
const _idleTimeout = Duration(seconds: 30);
int _counter = 0;

/// Descarga [url] a un archivo temporal y devuelve su ruta. Lanza si el
/// servidor no responde 200, si la conexión se queda inactiva o si el archivo
/// llega incompleto; en cualquier fallo no deja archivos parciales.
Future<String?> downloadTrack(
  String url, {
  void Function(int received, int? total)? onProgress,
}) async {
  final directory = await getTemporaryDirectory();
  final target = File(
    '${directory.path}${Platform.pathSeparator}audioshare_'
    '${DateTime.now().microsecondsSinceEpoch}_${_counter++}.mp3',
  );
  final client = http.Client();
  IOSink? sink;
  try {
    final response = await client.send(http.Request('GET', Uri.parse(url))).timeout(_headersTimeout);
    if (response.statusCode != 200) {
      throw HttpException('El servidor respondió HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final expected = response.contentLength;
    final encoding = response.headers['content-encoding'];
    final comparable = encoding == null || encoding == 'identity';
    sink = target.openWrite();
    var received = 0;
    await for (final chunk in response.stream.timeout(_idleTimeout)) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, expected);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    if (received == 0) throw const HttpException('La pista descargada está vacía');
    if (comparable && expected != null && received != expected) {
      throw HttpException('Descarga incompleta ($received de $expected bytes)');
    }
    return target.path;
  } catch (_) {
    try {
      await sink?.close();
    } catch (_) {}
    await deleteLocalTrack(target.path);
    rethrow;
  } finally {
    client.close();
  }
}

Future<void> deleteLocalTrack(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
