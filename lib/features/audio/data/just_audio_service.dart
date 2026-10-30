import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/audio_service.dart';
import 'track_downloader.dart';

/// Reproducción real con `just_audio`. El receptor descarga la pista con
/// [load], la coloca con [seek] y la arranca con [start] justo en `startAt`.
///
/// En Android/iOS/escritorio [load] baja el MP3 completo a un archivo local
/// antes de abrirlo: así `seek` y `play` no dependen de la red en el instante
/// crítico y "pista lista" significa realmente que el archivo está en el
/// teléfono. En Web no hay sistema de archivos y se usa la URL directamente.
///
/// El reproductor se crea bajo demanda, así que construir este servicio no
/// toca plugins nativos (útil en pruebas de widgets).
class JustAudioService implements AudioService {
  JustAudioService({AudioPlayer? player}) : _player = player;

  static const double defaultVolume = 0.8;

  AudioPlayer? _player;
  bool _loaded = false;
  String? _localPath;
  double _volume = defaultVolume;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  bool get isSimulated => false;

  @override
  Future<void> load(String url) async {
    String? downloaded;
    try {
      downloaded = await downloadTrack(url);
      if (downloaded != null) {
        await _p.setFilePath(downloaded);
      } else {
        await _p.setUrl(url);
      }
    } catch (_) {
      if (downloaded != null) await deleteLocalTrack(downloaded);
      rethrow;
    }
    final previous = _localPath;
    _localPath = downloaded;
    if (previous != null && previous != downloaded) await deleteLocalTrack(previous);
    await _p.setVolume(_volume);
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

  /// Volumen del reproductor de este dispositivo (0.0 a 1.0). Se recuerda
  /// aunque la pista aún no esté cargada y se aplica al cargarla.
  @override
  Future<void> setVolume(String receiverId, double volume) async {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    if (!_loaded) return;
    await _p.setVolume(_volume);
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _loaded = false;
    final path = _localPath;
    _localPath = null;
    if (path != null) await deleteLocalTrack(path);
  }
}
