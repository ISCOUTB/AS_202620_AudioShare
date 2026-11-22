import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/live/data/live_engine.dart';

void main() {
  // Carga el motor de audio en vivo desde el arranque: así desbloquear el audio
  // en el primer toque del usuario no depende de la red.
  preloadLiveAudio().ignore();
  runApp(const AudioShareApp());
}
