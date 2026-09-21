import 'package:flutter/material.dart';

import 'theme.dart';
import '../core/network/api_client.dart';
import '../features/session/data/repositories/room_repository.dart';
import '../features/session/presentation/pages/home_page.dart';

class AudioShareApp extends StatelessWidget {
  const AudioShareApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AudioShare',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomePage(repository: ApiRoomRepository(ApiClient())),
      );
}
