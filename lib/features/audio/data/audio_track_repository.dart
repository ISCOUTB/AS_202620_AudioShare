import 'dart:typed_data';

import '../../../core/network/api_client.dart';

abstract interface class AudioTrackRepository {
  Future<void> upload(String roomId, Uint8List bytes);
}

class ApiAudioTrackRepository implements AudioTrackRepository {
  ApiAudioTrackRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> upload(String roomId, Uint8List bytes) => _api.uploadBytes(
        '/rooms/${Uri.encodeComponent(roomId)}/track',
        bytes,
        contentType: 'audio/mpeg',
      );
}