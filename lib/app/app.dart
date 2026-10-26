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
    final ApiClient api;
    try {
      api = ApiClient();
    } on ApiConfigurationException catch (exception) {
      return MaterialApp(
        title: 'AudioShare',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración del servidor no válida',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(exception.message),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

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
