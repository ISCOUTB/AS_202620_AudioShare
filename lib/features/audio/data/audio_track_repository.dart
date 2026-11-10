import 'dart:typed_data';

import '../../../core/network/api_client.dart';

abstract interface class AudioTrackRepository {
  /// Sube (o reemplaza) la pista de la sala. [trackName] es el nombre que se
  /// muestra a los participantes.
  Future<void> upload(String roomId, Uint8List bytes, {String? trackName});
}

class ApiAudioTrackRepository implements AudioTrackRepository {
  ApiAudioTrackRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> upload(String roomId, Uint8List bytes, {String? trackName}) {
    final name = trackName?.trim();
    return _api.uploadBytes(
      '/rooms/${Uri.encodeComponent(roomId)}/track',
      bytes,
      contentType: 'audio/mpeg',
      headers: name == null || name.isEmpty
          ? const {}
          : {'X-Track-Name': Uri.encodeComponent(name)},
    );
  }
}
