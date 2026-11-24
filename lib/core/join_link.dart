import 'package:flutter/foundation.dart';

import 'network/api_client.dart';

/// Un código de sala tiene siempre 6 dígitos.
const roomCodeDigits = 6;

/// Enlace que abre AudioShare con el código de [code] ya escrito
/// (es lo que lleva el código QR de la sala).
String roomJoinLink(String code, {Uri? origin}) {
  final base = origin ?? _defaultOrigin();
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/',
    queryParameters: {'sala': code},
  ).toString();
}

/// Enlace que Chrome y Samsung Internet convierten en "abrir la app de Android"
/// con el código ya escrito. Si la app no está instalada, no hace nada.
String roomAppOpenLink(String code) =>
    'intent://join?sala=$code#Intent;scheme=audioshare;package=com.example.audioshare;end';

/// Código de sala que trae el enlace (`?sala=123456`), o `null` si no trae uno válido.
String? roomCodeFromLink(Uri uri) {
  final code = uri.queryParameters['sala'];
  if (code == null || code.length != roomCodeDigits || !RegExp(r'^\d+$').hasMatch(code)) {
    return null;
  }
  return code;
}

Uri _defaultOrigin() {
  if (kIsWeb) {
    final here = Uri.base;
    if ((here.scheme == 'http' || here.scheme == 'https') && here.host.isNotEmpty) {
      return Uri(scheme: here.scheme, host: here.host, port: here.hasPort ? here.port : null);
    }
  }
  return Uri.parse(ApiClient.publicServer);
}

/// Código de sala dentro de lo que leyó el lector de QR: el enlace de la sala
/// (web o `audioshare://`) o el código suelto de 6 dígitos. `null` si no es nada de eso.
String? roomCodeFromScan(String raw) {
  final text = raw.trim();
  if (text.length == roomCodeDigits && RegExp(r'^\d+$').hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  return uri == null ? null : roomCodeFromLink(uri);
}
