import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/pixel_font.dart';

const _frame = 1 / 60;

/// Steers for the middle of the gap a little ahead of the bunny.
void _autopilot(GameState game) {
  final (l, r) = game.wallAt(game.distance + game.height - (game.bunnyY - 60));
  game.pointerMove((l + r) / 2, game.height * 0.72);
}

void main() {
  test('the tunnel always leaves room for the bunny, and a careful player can go far', () {
    final game = GameState(seed: 1);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    var frames = 0;
    while (game.mode == GameMode.playing && frames < 60 * 120) {
      _autopilot(game);
      game.update(_frame);
      frames++;
      for (final s in game.walls) {
        expect(s.right - s.left, greaterThanOrEqualTo(96 - 1e-9)); // minimum gap, give or take rounding
        expect(s.left, greaterThanOrEqualTo(10));
        expect(s.right, lessThanOrEqualTo(GameState.width - 10));
      }
    }
    // past the point where difficulty tops out (40 screens) and still flying
    expect(game.screens, greaterThan(40));
  });

  test('the trail keeps the climb and folds back down when the bunny dives', () {
    final game = GameState(seed: 2);
    game.pointerDown(GameState.width / 2, 300);
    for (var i = 0; i < 60; i++) {
      game.update(_frame);
    }
    game.pointerMove(GameState.width / 2, game.height - 60); // dive
    for (var i = 0; i < 20; i++) {
      game.update(_frame);
    }
    final trail = game.trail;
    final folds = [for (var i = 1; i < trail.length; i++) trail[i].wy < trail[i - 1].wy];
    expect(folds.any((f) => f), isTrue, reason: 'newest points should head back down');
    final highest = trail.map((p) => p.wy).reduce(math.max);
    expect(highest, greaterThan(trail.last.wy + 100), reason: 'the earlier climb is still there');
  });

  test('a crash is saved and marked on the next run', () {
    SavedProgress? saved;
    final game = GameState(seed: 3, onSave: (p) => saved = p);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    game.pointerMove(GameState.width, game.height * 0.72); // hug the right wall
    for (var i = 0; i < 60 * 10 && game.mode == GameMode.playing; i++) {
      game.update(_frame);
    }
    expect(game.mode, GameMode.dead);
    expect(saved?.crashY, isNotNull);

    game.pointerUp();
    for (var i = 0; i < 60; i++) {
      game.update(_frame);
    }
    expect(game.canRetry, isTrue);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.mode, GameMode.playing);
    expect(game.marker?.wy, closeTo(saved!.crashY!, 1e-9));
  });

  test('restore brings back the best score and crash point', () {
    final game = GameState(seed: 4)..restore(const SavedProgress(best: 12, crashY: 900, crashX: 80));
    expect(game.best, 12);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.marker?.x, 80);
  });

  test('bonus zones open wide every N screens, with coins', () {
    const every = 2;
    final game = GameState(seed: 5, tuning: const GameTuning(bonusZoneEvery: every, openSectionChance: 0, powerUpChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    final wideAt = <double>[];
    var coinsSeen = 0;
    while (game.mode == GameMode.playing && game.screens < 7) {
      _autopilot(game);
      game.update(_frame);
      for (final s in game.walls) {
        if (s.wy > GameState.screenLength && s.right - s.left >= 345) wideAt.add(s.wy);
      }
      coinsSeen = math.max(coinsSeen, game.pickups.where((p) => p.isCoin).length);
    }
    expect(game.screens, greaterThanOrEqualTo(7));
    expect(wideAt, isNotEmpty);
    // the first zone starts right around the end of screen 2
    expect(wideAt.reduce(math.min), inInclusiveRange(every * GameState.screenLength - 50, every * GameState.screenLength + 400));
    // and later zones follow
    expect(wideAt.any((wy) => wy > 2 * every * GameState.screenLength), isTrue);
    expect(coinsSeen, greaterThan(15));
    expect(game.coins, greaterThan(0), reason: 'the autopilot flies through the coin snake');
  });

  test('walls still open up wide late in a fast run', () {
    // ordinary tunnel past screen 40 (full difficulty) is never wider than about 210
    final game =
        GameState(seed: 6, tuning: const GameTuning(bonusZoneEvery: 0, powerUpChance: 0, openSectionChance: 0.3));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    var lateWide = false;
    while (game.mode == GameMode.playing && game.screens < 55) {
      _autopilot(game);
      game.update(_frame);
      if (game.screens > 40) {
        lateWide = lateWide || game.walls.any((s) => s.right - s.left >= 285);
      }
    }
    expect(game.screens, greaterThanOrEqualTo(55));
    expect(lateWide, isTrue);
  });

  test('coins are banked and reported for saving', () {
    SavedProgress? saved;
    final game = GameState(seed: 9, onSave: (p) => saved = p)..restore(const SavedProgress(coins: 40));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    game.update(_frame);
    game.pickups.add(Pickup.coin(game.bunnyX, game.distance + game.height - game.bunnyY, 0));
    game.update(_frame);
    expect(game.runCoins, 1);
    expect(game.coins, 41);
    expect(saved?.coins, 41);
  });

  test('boost, slow and freeze scale the level speed, then wear off', () {
    final game = GameState(
        seed: 7,
        tuning: const GameTuning(boostSeconds: 2, slowSeconds: 2, freezeSeconds: 2, powerUpChance: 0, bonusZoneEvery: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    void fly(double seconds) {
      for (var i = 0; i < seconds * 60; i++) {
        _autopilot(game);
        game.update(_frame);
      }
    }

    fly(1.5);
    expect(game.speed / game.baseSpeed, closeTo(1, 0.01));

    game.applyPowerUp(PowerUp.boost);
    fly(1);
    expect(game.speed / game.baseSpeed, closeTo(1.25, 0.01), reason: '10 s per screen becomes 8 s');
    fly(1.5);
    expect(game.effect, isNull);
    expect(game.speed / game.baseSpeed, closeTo(1, 0.01));

    game.applyPowerUp(PowerUp.slow);
    fly(1);
    expect(game.speed / game.baseSpeed, closeTo(0.8, 0.01));
    fly(1.5);

    game.applyPowerUp(PowerUp.freeze);
    fly(1);
    expect(game.speed, lessThan(1));
    final frozenAt = game.distance;
    fly(0.5);
    expect(game.distance - frozenAt, lessThan(1), reason: 'the level stands still');
    expect(game.mode, GameMode.playing);
  });

  test('the shield takes a hit, halves the level speed, then catches up in a quarter of the time', () {
    final game = GameState(seed: 8, tuning: const GameTuning(shieldHitSlowSeconds: 2, powerUpChance: 0, bonusZoneEvery: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    for (var i = 0; i < 90; i++) {
      game.update(_frame); // let the start-of-run grace period pass
    }
    game.applyPowerUp(PowerUp.shield);
    game.pointerMove(GameState.width, game.height * 0.72); // fly into the right wall
    var frames = 0;
    while (game.shield && frames < 600) {
      game.update(_frame);
      frames++;
    }
    expect(game.shield, isFalse, reason: 'the shield was used up');
    expect(game.mode, GameMode.playing, reason: 'the hit did not end the run');

    void fly(double seconds) {
      for (var i = 0; i < seconds * 60; i++) {
        _autopilot(game);
        game.update(_frame);
      }
    }

    fly(0.5);
    expect(game.levelFactor, closeTo(0.5, 1e-9));
    fly(1.3); // 1.8 s after the hit: still slowed
    expect(game.levelFactor, closeTo(0.5, 1e-9));
    fly(0.45); // 2.25 s: halfway through the 0.5 s catch-up
    expect(game.levelFactor, inExclusiveRange(0.5, 1.0));
    fly(0.35); // 2.6 s: fully caught up
    expect(game.levelFactor, 1.0);
    expect(game.mode, GameMode.playing);
  });

  test('the run darkens as you climb, fully at the darkest screen, and a new run starts bright', () {
    final game = GameState(seed: 12, tuning: const GameTuning(darkestAtScreen: 6, bonusZoneEvery: 0));
    expect(game.mood, 0, reason: 'the title screen is bright');
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    final moods = <double>[];
    while (game.mode == GameMode.playing && game.screens < 7) {
      _autopilot(game);
      game.update(_frame);
      moods.add(game.mood);
    }
    expect(game.screens, greaterThanOrEqualTo(7));
    for (var i = 1; i < moods.length; i++) {
      expect(moods[i], greaterThanOrEqualTo(moods[i - 1]), reason: 'it only gets darker during a run');
    }
    expect(moods.firstWhere((m) => m > 0.45), lessThan(0.6));
    expect(game.mood, 1.0, reason: 'full night past screen 6');

    game.pointerMove(GameState.width, game.height * 0.72); // crash into the right wall
    for (var i = 0; i < 60 * 10 && game.mode == GameMode.playing; i++) {
      game.update(_frame);
    }
    expect(game.mode, GameMode.dead);
    expect(game.mood, 1.0, reason: 'the game-over screen keeps the mood of the crash');
    game.pointerUp();
    for (var i = 0; i < 70; i++) {
      game.update(_frame);
    }
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.mood, 0, reason: 'a new run starts bright');
  });

  test('every font glyph is 5x7 and the title letters exist', () {
    for (final ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?&':.,-+going".split('')) {
      expect(PixelFont.glyph(ch)?.length, 35, reason: 'glyph "$ch"');
    }
  });
}
