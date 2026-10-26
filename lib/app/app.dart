import 'package:flutter/material.dart';

import 'theme.dart';
import '../core/network/api_client.dart';
import '../features/audio/data/audio_track_repository.dart';
import '../features/audio/data/just_audio_service.dart';
import '../features/session/data/repositories/room_repository.dart';
import '../features/session/presentation/pages/home_page.dart';
import '../features/sync/data/sync_repository.dart';

class AudioShareApp extends StatelessWidget {
  const AudioShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MaterialApp(
      title: 'AudioShare',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(
        repository: ApiRoomRepository(api),
        syncRepository: ApiSyncRepository(api),
        api: api,
        audioFactory: JustAudioService.new,
        audioTrackRepository: ApiAudioTrackRepository(api),
      ),
    );
  }
}
