import 'dart:typed_data';

import 'package:audioshare/core/network/api_client.dart';
import 'package:audioshare/features/audio/data/audio_track_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sube los bytes MP3 al endpoint asociado a la sala', () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 201);
    });
    final repository = ApiAudioTrackRepository(
      ApiClient(client: client, baseUri: Uri.parse('https://audioshare.test')),
    );
    final bytes = Uint8List.fromList([0x49, 0x44, 0x33, 1, 2, 3]);

    await repository.upload('room-1', bytes);

    final request = requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/rooms/room-1/track');
    expect(request.headers['Content-Type'], 'audio/mpeg');
    expect(request.bodyBytes, bytes);
    client.close();
  });
}