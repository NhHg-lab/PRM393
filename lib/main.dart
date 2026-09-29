import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'controllers/game_controller.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final storage = StorageService();
  await storage.initialize();
  final gameController = GameController(
    storage: storage,
    audio: AudioService(),
  );
  await gameController.initialize();
  runApp(RunBetApp(controller: gameController));
}
