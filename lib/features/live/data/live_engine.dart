// Motor de audio en vivo según la plataforma: en Web usa `audioshare_live.js`;
// en el resto, un motor que explica que aún no está disponible.
export 'live_engine_stub.dart' if (dart.library.js_interop) 'live_engine_web.dart';
