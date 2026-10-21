// TEMPORARY: renders fixed game frames to PNG + raw RGBA so the picture can be compared
// before and after the CPU work. Deleted afterwards.
//   flutter test test/zz_frames_test.dart --dart-define=FRAMES_OUT=<dir>
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/starfield.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';

const _out = String.fromEnvironment('FRAMES_OUT');
const _w = 800, _h = 1600;

Future<void> _setUp(GoingUpGame game) async {
  game.onGameResize(Vector2(_w.toDouble(), _h.toDouble()));
  game.camera.backdrop = Starfield(random: math.Random(7)); // the stock one is unseeded
  await game.ready();
  game.update(0);
}

void _autopilot(GameState s) {
  final (l, r) = s.wallAt(s.distance + s.height - (s.bunnyY - 60));
  s.pointerMove((l + r) / 2, s.height * 0.72);
}

void _run(GoingUpGame game, int frames, [void Function(GameState s, int i)? steer]) {
  for (var i = 0; i < frames; i++) {
    steer?.call(game.state, i);
    game.update(1 / 60);
  }
}

Future<void> _capture(GoingUpGame game, String name) async {
  for (final p in game.world.children.whereType<ParticleSystemComponent>().toList()) {
    p.removeFromParent(); // particle bursts use an unseeded random
  }
  await game.ready();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, _w * 1.0, _h * 1.0), Paint()..color = game.backgroundColor());
  game.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_w, _h);
  final png = await image.toByteData(format: ImageByteFormat.png);
  final raw = await image.toByteData(format: ImageByteFormat.rawRgba);
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  File('$_out/$name.rgba').writeAsBytesSync(raw!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  // ignore: avoid_print
  print('captured $name (mode ${game.state.mode.name}, mood ${game.mood.toStringAsFixed(3)}, '
      'trail ${game.state.trail.length}, pickups ${game.state.pickups.length})');
}

void main() {
  if (_out.isEmpty) return;

  testWithGame<GoingUpGame>('title', () => GoingUpGame(state: GameState(seed: 1)), (game) async {
    await _setUp(game);
    game.state.restore(const SavedProgress(best: 12, coins: 34));
    _run(game, 30);
    await _capture(game, 'title_a');
    _run(game, 200);
    await _capture(game, 'title_b');
  });

  testWithGame<GoingUpGame>('early run with marker', () => GoingUpGame(state: GameState(seed: 2)), (game) async {
    await _setUp(game);
    game.state.restore(const SavedProgress(best: 3, coins: 5, crashY: 1300, crashX: 120));
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    _run(game, 150, (s, _) => _autopilot(s));
    await _capture(game, 'run_marker');
    _run(game, 150, (s, _) => _autopilot(s));
    await _capture(game, 'run_early');
  });

  testWithGame<GoingUpGame>(
      'bonus zone with power-ups', () => GoingUpGame(state: GameState(seed: 3, tuning: const GameTuning(bonusZoneEvery: 1))),
      (game) async {
    await _setUp(game);
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    _run(game, 240, (s, _) => _autopilot(s));
    game.state.applyPowerUp(PowerUp.shield);
    _run(game, 40, (s, _) => _autopilot(s));
    await _capture(game, 'bonus_a');
    // loop the loop inside the wide zone, so the trail crosses itself
    _run(game, 100, (s, i) {
      final a = i / 100 * 2 * math.pi;
      s.pointerMove(GameState.width / 2 + math.sin(a) * 90, s.height * 0.6 + math.cos(a) * 110);
    });
    await _capture(game, 'bonus_loop');
  });

  testWithGame<GoingUpGame>('dusk', () => GoingUpGame(state: GameState(seed: 4, tuning: const GameTuning(darkestAtScreen: 3))),
      (game) async {
    await _setUp(game);
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    _run(game, 400, (s, _) => _autopilot(s));
    await _capture(game, 'dusk');
  });

  testWithGame<GoingUpGame>(
      'night', () => GoingUpGame(state: GameState(seed: 5, tuning: const GameTuning(darkestAtScreen: 1, bonusZoneEvery: 3))),
      (game) async {
    await _setUp(game);
    game.state.restore(const SavedProgress(best: 30, coins: 99));
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    _run(game, 600, (s, _) => _autopilot(s));
    await _capture(game, 'night_a');
    _run(game, 37, (s, _) => _autopilot(s));
    await _capture(game, 'night_b');
    // crash in the dark and wait for the game-over screen
    _run(game, 600, (s, _) => s.mode == GameMode.playing ? s.pointerMove(GameState.width, s.height * 0.72) : null);
    await _capture(game, 'night_over');
  });

  testWithGame<GoingUpGame>('game over', () => GoingUpGame(state: GameState(seed: 3)), (game) async {
    await _setUp(game);
    game.state.restore(const SavedProgress(best: 1, coins: 1));
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    game.state.pointerMove(0, game.state.height * 0.72);
    _run(game, 600);
    await _capture(game, 'over');
    game.state.pointerUp();
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72); // retry: marker + ghost
    _run(game, 100, (s, _) => _autopilot(s));
    await _capture(game, 'retry');
  });
}
