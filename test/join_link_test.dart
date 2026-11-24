import 'package:audioshare/core/join_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roomJoinLink', () {
    test('arma el enlace con el código de la sala', () {
      expect(
        roomJoinLink('919513', origin: Uri.parse('https://audioshare.iscoutb.dev')),
        'https://audioshare.iscoutb.dev/?sala=919513',
      );
    });

    test('conserva el puerto cuando el servidor no usa el estándar', () {
      expect(
        roomJoinLink('123456', origin: Uri.parse('http://192.168.1.10:3000')),
        'http://192.168.1.10:3000/?sala=123456',
      );
    });
  });

  test('roomAppOpenLink apunta a la app con el código', () {
    expect(
      roomAppOpenLink('919513'),
      'intent://join?sala=919513#Intent;scheme=audioshare;package=com.example.audioshare;end',
    );
  });

  group('roomCodeFromLink', () {
    test('lee el código de un enlace válido', () {
      expect(roomCodeFromLink(Uri.parse('https://x.dev/?sala=919513')), '919513');
    });

    test('lee el código del enlace que abre la app', () {
      expect(roomCodeFromLink(Uri.parse('audioshare://join?sala=919513')), '919513');
    });

    test('ignora enlaces sin código o con un código inválido', () {
      expect(roomCodeFromLink(Uri.parse('https://x.dev/')), isNull);
      expect(roomCodeFromLink(Uri.parse('https://x.dev/?sala=12345')), isNull);
      expect(roomCodeFromLink(Uri.parse('https://x.dev/?sala=12a456')), isNull);
    });
  });

  group('roomCodeFromScan', () {
    test('acepta el enlace de la web, el de la app y el código suelto', () {
      expect(roomCodeFromScan('https://audioshare.iscoutb.dev/?sala=919513'), '919513');
      expect(roomCodeFromScan('audioshare://join?sala=919513'), '919513');
      expect(roomCodeFromScan(' 919513 '), '919513');
    });

    test('rechaza lo que no es de AudioShare', () {
      expect(roomCodeFromScan('https://ejemplo.com/'), isNull);
      expect(roomCodeFromScan('hola'), isNull);
      expect(roomCodeFromScan('12345'), isNull);
    });
  });
}
