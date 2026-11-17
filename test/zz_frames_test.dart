// Renders screens to PNG, to look at by eye. Skipped unless FRAMES_OUT is set:
//   flutter test test/zz_frames_test.dart --dart-define=FRAMES_OUT=<dir>
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/starfield.dart';
import 'package:goingup/game/components/versus_screen.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';
import 'package:goingup/game/versus/lan.dart';

const _out = String.fromEnvironment('FRAMES_OUT');
const _w = 800, _h = 1600;

Future<GoingUpGame> _game(GameState state, {Lan? lan}) async {
  final game = await initializeGame(() => GoingUpGame(state: state, lan: lan));
  game.onGameResize(Vector2(_w.toDouble(), _h.toDouble()));
  game.camera.backdrop = Starfield(random: math.Random(7));
  await game.ready();
  game.update(0);
  return game;
}

void _autopilot(GameState s) {
  s.grace = 1;
  final (l, r) = s.wallAt(s.distance + s.height - (s.bunnyY - 60));
  s.pointerMove((l + r) / 2, s.height * 0.72);
}

Future<void> _run(List<GoingUpGame> games, int frames, {bool steer = true}) async {
  for (var i = 0; i < frames; i++) {
    for (final g in games) {
      if (steer && g.state.mode == GameMode.playing) _autopilot(g.state);
      g.update(1 / 60);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _capture(GoingUpGame game, String name) async {
  for (final p in game.world.children.whereType<ParticleSystemComponent>().toList()) {
    p.removeFromParent();
  }
  await game.ready();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, _w * 1.0, _h * 1.0), Paint()..color = game.backgroundColor());
  game.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_w, _h);
  final png = await image.toByteData(format: ImageByteFormat.png);
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  // ignore: avoid_print
  print('captured $name (mode ${game.state.mode.name}, meters ${game.state.meters})');
}

void _press(GoingUpGame game, Rect rect) => game.press(Vector2(rect.center.dx, rect.center.dy), touch: true);

VersusButton _button(GoingUpGame game, String label) => game.versusScreen.buttons.firstWhere((b) => b.label == label);

void main() {
  if (_out.isEmpty) return;

  test('title, run and game over in meters', () async {
    final game = await _game(GameState(seed: 2)..restore(const SavedProgress(best: 143, coins: 2600)));
    await _run([game], 30);
    await _capture(game, 'title');
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    await _run([game], 400);
    await _capture(game, 'run');
    game.state
      ..grace = 0
      ..pointerMove(GameState.width, game.state.height * 0.72);
    await _run([game], 120, steer: false);
    await _capture(game, 'over');
  });

  test('the memory fork', () async {
    final game = await _game(GameState(seed: 3));
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    for (var i = 0; i < 60 * 40; i++) {
      await _run([game], 1);
      final memory = game.state.pickups.where((p) => p.memory != null).firstOrNull;
      if (memory != null && game.state.screenY(memory.wy) > game.state.height * 0.4) break;
    }
    await _capture(game, 'fork');
  });

  test('hollows in open space', () async {
    final game = await _game(GameState(seed: 5, tuning: const GameTuning(realmEveryMeters: 15)));
    game.state.pointerDown(GameState.width / 2, game.state.height * 0.72);
    for (var i = 0; i < 60 * 60; i++) {
      await _run([game], 1);
      if (game.state.hollows.any((h) => game.state.screenY(h.wy) > game.state.height * 0.35)) break;
    }
    await _capture(game, 'hollows');
  });

  test('the shop with perks', () async {
    final game = await _game(GameState(seed: 1)..restore(const SavedProgress(coins: 4200, owned: ['comet'])));
    await _run([game], 10);
    _press(game, game.shopButton);
    final shop = game.shop;
    _press(game, shop.nextPage);
    _press(game, shop.nextPage);
    await _run([game], 2);
    _press(game, shop.card(0));
    await _run([game], 20);
    await _capture(game, 'shop_last_page');
    _press(game, shop.prevPage);
    _press(game, shop.card(3));
    await _run([game], 20);
    await _capture(game, 'shop_guardian');
    _press(game, shop.tab(Shelf.trails));
    _press(game, shop.nextPage);
    _press(game, shop.card(4));
    await _run([game], 20);
    await _capture(game, 'shop_magnet');
  });

  test('two players', () async {
    final network = MemoryNetwork();
    final host = await _game(
        GameState(seed: 1)..restore(const SavedProgress(owned: ['mint', 'fire'], skin: 'mint', trail: 'fire')),
        lan: network.lan());
    final guest =
        await _game(GameState(seed: 2)..restore(const SavedProgress(owned: ['ember'], skin: 'ember')), lan: network.lan());
    _press(host, host.versusButton);
    await _run([host, guest], 2);
    await _capture(host, 'versus_menu');
    _press(host, _button(host, 'HOST A GAME').rect);
    await _run([host, guest], 2);
    await _capture(host, 'versus_hosting');
    _press(guest, guest.versusButton);
    _press(guest, _button(guest, 'JOIN A GAME').rect);
    await _run([host, guest], 3);
    await _capture(guest, 'versus_found');
    _press(guest, guest.versusScreen.buttons.firstWhere((b) => b.game != null).rect);
    await _run([host, guest], 3);
    await _capture(host, 'versus_lobby_host');
    await _capture(guest, 'versus_lobby_guest');
    _press(host, _button(host, 'START').rect);
    await _run([host, guest], 50);
    await _capture(guest, 'versus_countdown');
    host.state.pointerDown(GameState.width / 2, host.state.height * 0.72);
    guest.state.pointerDown(GameState.width / 2, guest.state.height * 0.72);
    await _run([host, guest], 140);
    await _capture(guest, 'versus_go');
    for (var i = 0; i < 400; i++) {
      // the guest weaves a little to the side of the host
      _autopilot(host.state);
      _autopilot(guest.state);
      guest.state.pointerMove(guest.state.bunnyX + math.sin(i / 20) * 30, guest.state.height * 0.62);
      host.update(1 / 60);
      guest.update(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }
    await _capture(guest, 'versus_race');
    // the host's shield takes a hit and the level slows down, so the guest pulls ahead out of sight
    host.state.applyPowerUp(PowerUp.shield);
    host.state
      ..grace = 0
      ..pointerMove(GameState.width, host.state.height * 0.72);
    for (var i = 0; i < 300 && host.state.shield; i++) {
      _autopilot(guest.state);
      host.update(1 / 60);
      guest.update(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }
    await _run([host, guest], 150);
    await _capture(guest, 'versus_ahead');
    await _capture(host, 'versus_behind');
    for (var i = 0; i < 400 && !(guest.state.showGameOver && host.state.showGameOver); i++) {
      host.state
        ..grace = 0
        ..pointerMove(0, host.state.height * 0.72);
      _autopilot(guest.state);
      host.update(1 / 60);
      guest.update(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }
    await _run([host, guest], 30, steer: false);
    await _capture(guest, 'versus_won');
    _press(guest, guest.rematchButton);
    await _run([host, guest], 3, steer: false);
    await _capture(host, 'versus_lost');
    host.onRemove();
    guest.onRemove();
  });
}
