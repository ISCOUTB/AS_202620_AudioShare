abstract interface class AudioService {
  bool get isSimulated;

  /// Descarga y prepara la pista [url] (sin reproducirla). Debe llamarse antes
  /// de la cuenta atrás para que el arranque en `startAt` sea inmediato.
  Future<void> load(String url);

  /// Coloca la pista en [positionMs] (0 al iniciar; la posición de pausa al
  /// reanudar). No reproduce.
  Future<void> seek(int positionMs);

  Future<void> start();
  Future<void> pause();
  Future<void> setVolume(String receiverId, double volume);
  Future<void> dispose();
}

/// Opcional: reproductores que conocen la duración de la pista cargada. Va
/// aparte de [AudioService] para no obligar a quien ya lo implementa a añadirla.
abstract interface class DurationProvider {
  /// Duración de la pista cargada en milisegundos; null si aún no se conoce.
  int? get durationMs;
}

class MockAudioService implements AudioService {
  final Map<String, double> volumes = {};

  @override
  bool get isSimulated => true;

  @override
  Future<void> load(String url) async {}

  @override
  Future<void> seek(int positionMs) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> setVolume(String receiverId, double volume) async {
    volumes[receiverId] = volume;
  }

  @override
  Future<void> dispose() async {}
}
