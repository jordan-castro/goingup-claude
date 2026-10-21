import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_screen.dart';
import 'game/palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu(); // right-click shouldn't pop a menu over the game
  } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const GoingUpApp());
}

class GoingUpApp extends StatelessWidget {
  const GoingUpApp({super.key, this.music = true});

  /// Whether to play the soundtrack (tests turn it off).
  final bool music;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'goingUP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.page,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.hot, brightness: Brightness.dark),
      ),
      home: Scaffold(body: GameScreen(music: music)),
    );
  }
}
