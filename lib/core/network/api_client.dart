import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        baseUri = baseUri ?? _defaultBaseUri();

  final http.Client _client;

  /// Dirección del backend. Se puede cambiar en tiempo de ejecución (campo
  /// "Servidor" de la pantalla inicial) para usar la IP del equipo en la LAN.
  Uri baseUri;

  /// URL absoluta de [path] en el backend (p. ej. `/track`).
  Uri resolve(String path) => baseUri.resolve(path);

  static Uri _defaultBaseUri() {
    const configuredApiUrl = String.fromEnvironment('AUDIOSHARE_API_URL');

    if (configuredApiUrl.isNotEmpty) {
      return Uri.parse(configuredApiUrl);
    }

    if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
      final codespacesHost = Uri.base.host.replaceFirst(
        RegExp(r'-8080(?=\.)'),
        '-3000',
      );
      final isCodespaces = codespacesHost != Uri.base.host;
      final webPort = Uri.base.port == 8080 ? 3000 : Uri.base.port;

      return Uri(
        scheme: Uri.base.scheme,
        host: isCodespaces ? codespacesHost : Uri.base.host,
        port: isCodespaces ? Uri.base.port : webPort,
        path: '',
        query: '',
        fragment: '',
      );
    }
    return Uri.parse('http://10.0.2.2:3000');
  }

  /// Abre una respuesta NDJSON y emite cada línea no vacía a medida que llega.
  /// Cancelar la suscripción cierra la conexión. Un estado distinto de 2xx
  /// lanza [ApiException].
  Stream<String> openLines(String path) async* {
    final uri = baseUri.resolve(path);
    final response = await _client.send(http.Request('GET', uri));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      var message = 'Error de comunicación';
      try {
        message = (jsonDecode(text) as Map)['error'] as String? ?? message;
      } catch (_) {}
      throw ApiException(message, statusCode: response.statusCode);
    }
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = baseUri.resolve(path);
    final response = await _client.send(
      http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = body == null ? '' : jsonEncode(body),
    );
    final text = await response.stream.bytesToString();
    Map<String, dynamic> data;
    try {
      data = (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ApiException(
        'El servidor devolvió una respuesta inválida '
        '(HTTP ${response.statusCode}) desde ${uri.origin}',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['error'] as String? ?? 'Error de comunicación',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
