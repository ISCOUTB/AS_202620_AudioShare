abstract interface class AudioService {
  bool get isSimulated;
  Future<void> start();
  Future<void> pause();
  Future<void> setVolume(String receiverId, double volume);
}

class MockAudioService implements AudioService {
  final Map<String, double> volumes = {};

  @override
  bool get isSimulated => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> setVolume(String receiverId, double volume) async {
    volumes[receiverId] = volume;
  }
}
