import 'package:shared_preferences/shared_preferences.dart';

/// La sala de la que este dispositivo es emisor, con la llave que le dio el
/// servidor. Sin ella no se puede volver a controlar la sala (ADR-0014).
class EmitterSession {
  const EmitterSession({
    required this.roomId,
    required this.emitterId,
    required this.emitterKey,
  });

  final String roomId;
  final String emitterId;
  final String emitterKey;
}

/// Guarda como máximo una sala activa por dispositivo.
abstract interface class EmitterSessionStore {
  Future<EmitterSession?> load();
  Future<void> save(EmitterSession session);
  Future<void> clear();
}

class MemoryEmitterSessionStore implements EmitterSessionStore {
  EmitterSession? _session;

  @override
  Future<EmitterSession?> load() async => _session;

  @override
  Future<void> save(EmitterSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

class SharedPreferencesEmitterSessionStore implements EmitterSessionStore {
  static const _roomKey = 'emitter.roomId';
  static const _idKey = 'emitter.emitterId';
  static const _secretKey = 'emitter.key';

  @override
  Future<EmitterSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString(_roomKey);
    final emitterId = prefs.getString(_idKey);
    final emitterKey = prefs.getString(_secretKey);
    if (roomId == null || emitterId == null || emitterKey == null) return null;
    return EmitterSession(roomId: roomId, emitterId: emitterId, emitterKey: emitterKey);
  }

  @override
  Future<void> save(EmitterSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomKey, session.roomId);
    await prefs.setString(_idKey, session.emitterId);
    await prefs.setString(_secretKey, session.emitterKey);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roomKey);
    await prefs.remove(_idKey);
    await prefs.remove(_secretKey);
  }
}
