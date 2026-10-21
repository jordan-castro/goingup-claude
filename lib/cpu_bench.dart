// TEMPORARY profiling harness (deleted after the CPU work). Build with
//   flutter build windows --release -t lib/cpu_bench.dart
// and run goingup.exe <title|run|dark> [skip...] where skip names are tunnel, trail, pickups,
// marker, bunny, starfield, atmosphere, hud, music.
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/components/atmosphere.dart';
import 'game/components/bunny.dart';
import 'game/components/crash_marker.dart';
import 'game/components/hud.dart';
import 'game/components/pickups.dart';
import 'game/components/starfield.dart';
import 'game/components/trail.dart';
import 'game/components/tunnel.dart';
import 'game/game_state.dart';
import 'game/going_up_game.dart';
import 'game/music.dart';
import 'game/palette.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = args.isNotEmpty ? args.first : 'title';
  final skip = args.skip(1).toSet();
  final state = GameState(seed: 1, tuning: mode == 'dark' ? const GameTuning(darkestAtScreen: 1) : const GameTuning());
  final game = _BenchGame(mode, skip, state, skip.contains('music') ? SilentMusic() : LayeredMusic());
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Palette.page),
    home: Scaffold(body: GameWidget(game: game)),
  ));
}

class _BenchGame extends GoingUpGame {
  _BenchGame(this.mode, this.skip, GameState state, GameMusic music) : super(state: state, music: music);

  final String mode;
  final Set<String> skip;
  int _frames = 0;

  static const _types = {
    'tunnel': Tunnel,
    'trail': Trail,
    'pickups': PickupLayer,
    'marker': CrashMarkerView,
    'bunny': BunnyView,
    'starfield': Starfield,
    'atmosphere': Atmosphere,
    'hud': Hud,
  };

  void _strip() {
    final types = {for (final s in skip) ?_types[s]};
    for (final c in [...world.children, ...camera.viewport.children]) {
      if (types.contains(c.runtimeType)) c.removeFromParent();
    }
    if (types.contains(Starfield)) camera.backdrop = Component();
  }

  @override
  void update(double dt) {
    if (++_frames == 3) _strip();
    if (mode != 'title') {
      if (state.mode == GameMode.playing) {
        final (l, r) = state.wallAt(state.distance + state.height - (state.bunnyY - 60));
        state.pointerMove((l + r) / 2, state.height * 0.72);
      } else if (state.mode == GameMode.title || state.canRetry) {
        state.pointerDown(GameState.width / 2, state.height * 0.72);
      }
    }
    super.update(dt);
  }
}
