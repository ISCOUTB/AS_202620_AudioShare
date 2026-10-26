import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum ApiFailureKind { configuration, connection, timeout, http, invalidResponse }

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiFailureKind.http,
  });

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  @override
  String toString() => message;
}

class ApiConfigurationException extends ApiException {
  const ApiConfigurationException(super.message)
      : super(kind: ApiFailureKind.configuration);
}

class ApiClient {
  ApiClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        baseUri = baseUri ?? _defaultBaseUri();

  final http.Client _client;
  static const _requestTimeout = Duration(seconds: 15);

  /// Dirección del backend. Se puede cambiar en tiempo de ejecución (campo
  /// "Servidor" de la pantalla inicial) para usar la IP del equipo en la LAN.
  Uri baseUri;

  /// URL absoluta de [path] en el backend (p. ej. `/track`).
  Uri resolve(String path) => baseUri.resolve(path);

  /// Backend público utilizado por clientes nativos si no se configura uno.
  static const publicServer = 'https://audioshare.iscoutb.dev';

  static const _configuredApiUrl = String.fromEnvironment(
    'AUDIOSHARE_API_URL',
    defaultValue: '',
  );

  static Uri resolveBaseUri(
    Uri origin, {
    String? configuredApiUrl,
    bool? isWeb,
    bool? releaseMode,
  }) {
    final hasOverride = configuredApiUrl != null || _configuredApiUrl.isNotEmpty;
    if (hasOverride) {
      final rawUrl = (configuredApiUrl ?? _configuredApiUrl).trim();
      if (rawUrl.isEmpty) {
        throw const ApiConfigurationException(
          'AUDIOSHARE_API_URL está definida, pero no contiene una URL.',
        );
      }
      return _parseConfiguredUrl(rawUrl, releaseMode: releaseMode ?? kReleaseMode);
    }

    if (isWeb ?? kIsWeb) {
      if ((origin.scheme != 'http' && origin.scheme != 'https') ||
          origin.host.isEmpty) {
        throw const ApiConfigurationException(
          'No se pudo determinar el origen HTTP de AudioShare.',
        );
      }

      final codespacesPort = RegExp(r'-(\d+)\.app\.github\.dev$')
          .firstMatch(origin.host.toLowerCase())
          ?.group(1);
      if (codespacesPort != null && codespacesPort != '3000') {
        throw const ApiConfigurationException(
          'Flutter Web está en un puerto distinto al backend. Configura '
          'AUDIOSHARE_API_URL explícitamente o abre AudioShare desde el '
          'puerto 3000, que sirve la API y la aplicación en el mismo origen.',
        );
      }

      if ((origin.host == 'localhost' || origin.host == '127.0.0.1') &&
          origin.port == 8080) {
        throw const ApiConfigurationException(
          'Flutter Web está en localhost:8080, separado del backend. '
          'Configura AUDIOSHARE_API_URL=http://localhost:3000.',
        );
      }

      return Uri.parse(origin.origin);
    }

    return Uri.parse(publicServer);
  }

  static Uri _parseConfiguredUrl(String rawUrl, {required bool releaseMode}) {
    final Uri uri;
    try {
      uri = Uri.parse(rawUrl);
    } on FormatException {
      throw const ApiConfigurationException(
        'AUDIOSHARE_API_URL no es una URL válida.',
      );
    }

    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiConfigurationException(
        'AUDIOSHARE_API_URL debe ser el origen HTTP(S) del backend, sin '
        'credenciales, ruta, query ni fragmento.',
      );
    }

    final host = uri.host.toLowerCase();
    final isLocalhost = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost');
    final isCodespaces = host.endsWith('.app.github.dev') ||
        host == 'github.dev' ||
        host.endsWith('.github.dev');
    if (releaseMode && (uri.scheme != 'https' || isLocalhost || isCodespaces)) {
      throw const ApiConfigurationException(
        'La compilación de producción requiere un backend HTTPS público; '
        'no puede usar localhost ni un host temporal de Codespaces.',
      );
    }

    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null);
  }

  static Uri _defaultBaseUri() => resolveBaseUri(Uri.base);

  /// Abre una respuesta NDJSON y emite cada línea no vacía a medida que llega.
  /// Cancelar la suscripción cierra la conexión. Un estado distinto de 2xx
  /// lanza [ApiException].
  Stream<String> openLines(String path) async* {
    final uri = baseUri.resolve(path);
    final response = await _send(http.Request('GET', uri), uri, 'GET $path');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      throw _httpError(response.statusCode, text, uri);
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
    final request = http.Request(method, uri);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _send(request, uri, '$method $path');
    final text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response.statusCode, text, uri);
    }

    Map<String, dynamic> data;
    try {
      data = (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ApiException(
        'El backend respondió, pero devolvió JSON inválido en ${uri.origin}.',
        kind: ApiFailureKind.invalidResponse,
      );
    }
    return data;
  }

  Future<void> uploadBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final uri = baseUri.resolve(path);
    final response = await _send(
      http.Request('POST', uri)
        ..headers['Content-Type'] = contentType
        ..bodyBytes = bytes,
      uri,
      'POST $path',
    );
    final text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response.statusCode, text, uri);
    }
  }

  Future<http.StreamedResponse> _send(
    http.BaseRequest request,
    Uri uri,
    String operation,
  ) async {
    if (kDebugMode) {
      debugPrint('AudioShare API $operation -> ${uri.origin}');
    }
    try {
      return await _client.send(request).timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Tiempo de espera agotado al conectar con ${uri.origin} ($operation).',
        kind: ApiFailureKind.timeout,
      );
    } on http.ClientException catch (exception) {
      throw ApiException(
        'No se obtuvo respuesta de ${uri.origin} ($operation): ${exception.message}. '
        'Comprueba que el backend sea accesible y que HTTPS y CORS permitan '
        'este origen; el navegador no permite distinguir aquí entre esas causas.',
        kind: ApiFailureKind.connection,
      );
    }
  }

  ApiException _httpError(int statusCode, String text, Uri uri) {
    var message = 'El backend respondió HTTP $statusCode en ${uri.origin}.';
    try {
      final error = (jsonDecode(text) as Map)['error'];
      if (error is String && error.isNotEmpty) message = error;
    } on FormatException {
      // Keep the HTTP status visible when a proxy returns non-JSON content.
    } on TypeError {
      // Keep the HTTP status visible when the JSON shape is unexpected.
    }
    return ApiException(message, statusCode: statusCode, kind: ApiFailureKind.http);
  }
}
