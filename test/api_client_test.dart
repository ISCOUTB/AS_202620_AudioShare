import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:audioshare/core/network/api_client.dart';

void main() {
  group('ApiClient.resolveBaseUri', () {
    test('usa el mismo origen cuando web sirve API y frontend juntos', () {
      final uri = ApiClient.resolveBaseUri(
        Uri.parse('http://localhost:3000/'),
        isWeb: true,
      );

      expect(uri.toString(), 'http://localhost:3000');
    });

    test('usa el mismo origen del dominio público en producción web', () {
      final uri = ApiClient.resolveBaseUri(
        Uri.parse('https://audioshare.iscoutb.dev/'),
        isWeb: true,
      );

      expect(uri.toString(), 'https://audioshare.iscoutb.dev');
    });

    test('no inventa el backend a partir del host temporal de Codespaces', () {
      expect(
        () => ApiClient.resolveBaseUri(
          Uri.parse('https://unhallowed-spooky-vampire-97vqrvqx963p4w5-8080.app.github.dev'),
          isWeb: true,
        ),
        throwsA(isA<ApiConfigurationException>()),
      );
    });

    test('acepta una URL explícita para desarrollo en Codespaces', () {
      final uri = ApiClient.resolveBaseUri(
        Uri.parse('https://unhallowed-spooky-vampire-97vqrvqx963p4w5-8080.app.github.dev'),
        configuredApiUrl:
            'https://unhallowed-spooky-vampire-97vqrvqx963p4w5-3000.app.github.dev',
        isWeb: true,
      );

      expect(
        uri.toString(),
        'https://unhallowed-spooky-vampire-97vqrvqx963p4w5-3000.app.github.dev',
      );
    });

    test('no acepta una URL temporal o local en una compilación de producción', () {
      expect(
        () => ApiClient.resolveBaseUri(
          Uri.parse('https://audioshare.iscoutb.dev'),
          configuredApiUrl: 'http://localhost:3000',
          isWeb: true,
          releaseMode: true,
        ),
        throwsA(isA<ApiConfigurationException>()),
      );

      expect(
        () => ApiClient.resolveBaseUri(
          Uri.parse('https://audioshare.iscoutb.dev'),
          configuredApiUrl:
              'https://unhallowed-spooky-vampire-97vqrvqx963p4w5-3000.app.github.dev',
          isWeb: true,
          releaseMode: true,
        ),
        throwsA(isA<ApiConfigurationException>()),
      );
    });

    test('exige URL explícita cuando Flutter Web está separado en localhost:8080', () {
      expect(
        () => ApiClient.resolveBaseUri(
          Uri.parse('http://localhost:8080'),
          isWeb: true,
        ),
        throwsA(isA<ApiConfigurationException>()),
      );
    });

    test('rechaza overrides que no sean un origen HTTP(S)', () {
      expect(
        () => ApiClient.resolveBaseUri(
          Uri.parse('https://audioshare.iscoutb.dev'),
          configuredApiUrl: 'https://api.example.test/v1',
          isWeb: true,
        ),
        throwsA(isA<ApiConfigurationException>()),
      );
    });

    test('clientes nativos usan el backend público de producción', () {
      final uri = ApiClient.resolveBaseUri(
        Uri.parse('file:///app'),
        isWeb: false,
      );

      expect(uri.toString(), ApiClient.publicServer);
    });
  });

  group('ApiClient.request', () {
    test('distingue un fallo de conexión de una respuesta HTTP', () async {
      final client = ApiClient(
        client: MockClient((request) async {
          throw http.ClientException('Failed to fetch', request.url);
        }),
        baseUri: Uri.parse('https://backend.example.test'),
      );

      await expectLater(
        client.request('GET', '/rooms'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiFailureKind.connection)
              .having((error) => error.message, 'message', contains('backend.example.test')),
        ),
      );
    });

    test('conserva el estado HTTP cuando el proxy devuelve HTML', () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response('<html>not found</html>', 404)),
        baseUri: Uri.parse('https://backend.example.test'),
      );

      await expectLater(
        client.request('GET', '/rooms'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiFailureKind.http)
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('identifica JSON inválido en una respuesta exitosa', () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response('<html>wrong app</html>', 200)),
        baseUri: Uri.parse('https://backend.example.test'),
      );

      await expectLater(
        client.request('GET', '/rooms/room-1'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiFailureKind.invalidResponse)
              .having((error) => error.message, 'message', contains('JSON inválido')),
        ),
      );
    });
  });
}
