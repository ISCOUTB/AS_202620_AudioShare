// ignore_for_file: avoid_print
import 'package:audioshare/features/audio/data/just_audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

const trackUrl = 'http://127.0.0.1:3000/track';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'JustAudioService decodifica, reproduce y pausa el MP3 del servidor',
    () async {
      final player = AudioPlayer();
      final service = JustAudioService(player: player);
      addTearDown(service.dispose);

      print('audio-test: before load');
      await service.load(trackUrl);
      print('audio-test: after load ${player.duration}');
      expect(player.duration, isNotNull);
      expect(player.duration!.inMilliseconds, greaterThan(1000));

      await service.start();
      print('audio-test: after start');
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(player.playing, isTrue);
      expect(player.position.inMilliseconds, greaterThan(1000));

      await service.pause();
      print('audio-test: after pause');
      expect(player.playing, isFalse);
    },
    skip: !kIsWeb ? 'La reproducción real se valida en Chrome.' : false,
    timeout: const Timeout(Duration(seconds: 20)),
  );
}