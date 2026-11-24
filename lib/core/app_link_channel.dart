import 'package:flutter/services.dart';

import 'join_link.dart';

const _channel = MethodChannel('audioshare/links');

/// Recibe en la app de Android los enlaces `audioshare://join?sala=123456`
/// y entrega el código de sala que traen.
class AppLinkChannel {
  const AppLinkChannel._();

  /// Código del enlace con el que se abrió la app, si la abrieron con uno.
  static Future<String?> initialRoomCode() async {
    try {
      final raw = await _channel.invokeMethod<String>('initialLink');
      return raw == null ? null : roomCodeFromLink(Uri.parse(raw));
    } on MissingPluginException {
      return null; // plataforma sin este canal (web, Windows)
    } on PlatformException {
      return null;
    }
  }

  /// Avisa cada vez que llega un enlace con la app ya abierta.
  static void listen(void Function(String code) onCode) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'link') return;
      final raw = call.arguments;
      if (raw is! String) return;
      final code = roomCodeFromLink(Uri.parse(raw));
      if (code != null) onCode(code);
    });
  }

  static void stopListening() => _channel.setMethodCallHandler(null);
}
