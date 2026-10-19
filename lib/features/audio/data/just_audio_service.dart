import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/audio_service.dart';

/// Reproducción real con `just_audio`. El receptor descarga la pista con
/// [load], la coloca con [seek] y la arranca con [start] justo en `startAt`.
///
/// El reproductor se crea bajo demanda, así que construir este servicio no
/// toca plugins nativos (útil en pruebas de widgets).
class JustAudioService implements AudioService {
  JustAudioService({AudioPlayer? player}) : _player = player;

  AudioPlayer? _player;
  bool _loaded = false;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  bool get isSimulated => false;

  @override
  Future<void> load(String url) async {
    await _p.setUrl(url);
    _loaded = true;
  }

  @override
  Future<void> seek(int positionMs) async {
    if (!_loaded) return;
    await _p.seek(Duration(milliseconds: positionMs));
  }

  @override
  Future<void> start() async {
    if (!_loaded) return; // el emisor no tiene pista cargada: solo controla
    // `play()` termina cuando acaba la pista, por eso no se espera.
    unawaited(_p.play());
  }

  @override
  Future<void> pause() async {
    if (!_loaded) return;
    await _p.pause();
  }

  /// Volumen del reproductor de este dispositivo (0.0 a 1.0).
  @override
  Future<void> setVolume(String receiverId, double volume) async {
    if (!_loaded) return;
    await _p.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _loaded = false;
  }
}
