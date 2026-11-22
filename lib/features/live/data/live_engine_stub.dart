import '../domain/live_audio_engine.dart';

LiveAudioEngine createLiveAudioEngine() => UnsupportedLiveAudioEngine();

/// En plataformas sin motor no hay nada que cargar.
Future<void> preloadLiveAudio() async {}
