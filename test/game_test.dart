import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/pixel_font.dart';

/// Flies with the autopilot (passing through walls and hollows) until [done] or 2 minutes.
void _flyUntil(GameState game, bool Function() done) {
  for (var i = 0; i < 60 * 120 && game.mode == GameMode.playing && !done(); i++) {
    game.grace = 1;
    _autopilot(game);
    game.update(_frame);
  }
}

const _frame = 1 / 60;

/// Steers for the middle of the gap a little ahead of the bunny.
void _autopilot(GameState game) {
  final (l, r) = game.wallAt(game.distance + game.height - (game.bunnyY - 60));
  game.pointerMove((l + r) / 2, game.height * 0.72);
}

void main() {
  test('the tunnel always leaves room for the bunny, and a careful player can go far', () {
    final game = GameState(seed: 1, tuning: const GameTuning(hollowChance: 0)); // this autopilot can't dodge
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
    final game = GameState(
        seed: 6, tuning: const GameTuning(bonusZoneEvery: 0, powerUpChance: 0, openSectionChance: 0.3, hollowChance: 0));
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

  test('a quick run of coins climbs the scale, and the big moments make a sound', () {
    final game = GameState(seed: 9, tuning: const GameTuning(powerUpChance: 0, bonusZoneEvery: 0, openSectionChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.sounds.map((c) => c.sfx), [Sfx.takeoff, Sfx.memory], reason: 'the first run: "I woke up flying"');
    game.sounds.clear();

    void take(Pickup Function(double x, double wy) make) {
      game.pickups.add(make(game.bunnyX, game.worldY(game.bunnyY)));
      _autopilot(game);
      game.update(_frame);
    }

    for (var i = 0; i < 7; i++) {
      take((x, wy) => Pickup.coin(x, wy, 0));
      for (var f = 0; f < 6; f++) {
        _autopilot(game);
        game.update(_frame); // a tenth of a second between coins
      }
    }
    expect(game.sounds.map((c) => c.sfx).toSet(), {Sfx.coin});
    expect(game.sounds.map((c) => c.step), [0, 1, 2, 3, 4, 4, 4], reason: 'up the scale, then stays at the top');
    game.sounds.clear();

    for (var f = 0; f < 60; f++) {
      _autopilot(game);
      game.update(_frame);
    }
    take((x, wy) => Pickup.coin(x, wy, 0));
    expect(game.sounds.single.step, 0, reason: 'after a pause the scale starts again');
    game.sounds.clear();

    take((x, wy) => Pickup.powerUp(x, wy, PowerUp.shield, 0));
    expect(game.sounds.map((c) => c.sfx), [Sfx.shield]);
    game.sounds.clear();

    game.pointerMove(GameState.width, game.height * 0.72); // crash into the right wall
    for (var i = 0; i < 60 * 10 && game.mode == GameMode.playing; i++) {
      game.update(_frame);
    }
    expect(game.mode, GameMode.dead);
    expect(game.sounds.last.sfx, Sfx.crash);
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

  test('hollows wait until late in a run, and always leave a way past', () {
    final game = GameState(seed: 21);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    int? firstScreen;
    final seen = <Hollow>{};
    var warned = false;
    while (game.mode == GameMode.playing && game.screens < 60) {
      game.grace = 1; // fly straight through everything: this test only looks at the layout
      _autopilot(game);
      game.update(_frame);
      warned = warned || game.toast == 'THEY FOUND YOU.';
      for (final g in game.hollows) {
        if (seen.add(g)) firstScreen ??= game.screens;
        final sy = game.screenY(g.wy);
        if (sy < 0 || sy > game.height) continue; // walls are only known around the screen
        final (l, r) = game.wallAt(g.wy);
        expect(g.x - Hollow.radius, greaterThanOrEqualTo(l), reason: 'clear of the left wall');
        expect(g.x + Hollow.radius, lessThanOrEqualTo(r), reason: 'clear of the right wall');
        final room = math.max(g.x - Hollow.radius - l, r - g.x - Hollow.radius);
        expect(room, greaterThanOrEqualTo(56), reason: 'one side always has room for the bunny');
      }
    }
    expect(game.screens, 60);
    expect(firstScreen, isNotNull);
    expect(firstScreen, greaterThanOrEqualTo(const GameTuning().hollowsFromScreen - 1),
        reason: 'hollows are planned a little ahead of the screen they appear on');
    expect(seen.length, greaterThan(4));
    expect(warned, isTrue, reason: 'the first hollow of a run comes with a warning');
  });

  test('a Hollow One ends the run, the shield pops one, and they hop with a warning', () {
    final game = GameState(seed: 22, tuning: const GameTuning(powerUpChance: 0, bonusZoneEvery: 0, hollowChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    void fly(double seconds) {
      for (var i = 0; i < seconds * 60; i++) {
        _autopilot(game);
        game.update(_frame);
      }
    }

    fly(1.5); // past the start-of-run grace period
    Hollow atBunny() => Hollow(game.worldY(game.bunnyY), game.bunnyX, 0, 0, 0);

    game.applyPowerUp(PowerUp.shield);
    game.sounds.clear();
    game.hollows.add(atBunny());
    game.update(_frame);
    expect(game.mode, GameMode.playing);
    expect(game.shield, isFalse);
    expect(game.hollows, isEmpty, reason: 'the shield popped it');
    expect(game.sounds.map((c) => c.sfx), contains(Sfx.hollowPop));

    fly(2.5); // grace, slowdown and catch-up
    // it hops rather than drifts: it waits at a spot, crouches, then leaps to the next
    final hopper = Hollow(game.distance + game.height + 200, GameState.width / 2, 40, 2, 0);
    game.hollows.add(hopper);
    final xs = <double>[], crouches = <double>[];
    for (var i = 0; i < 180; i++) {
      game.update(_frame);
      xs.add(hopper.x);
      crouches.add(hopper.crouch);
    }
    final still = [for (var i = 1; i < xs.length; i++) (xs[i] - xs[i - 1]).abs() < 0.01].where((s) => s).length;
    expect(still, greaterThan(60), reason: 'it waits between leaps');
    expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(30), reason: 'and it does leap');
    expect(crouches.any((c) => c > 0.9), isTrue, reason: 'it crouches first: the warning');

    game.hollows.add(atBunny());
    game.update(_frame);
    expect(game.mode, GameMode.dead);
    expect(game.spooked, isTrue, reason: 'the game-over screen says GOT YOU. instead of BONK!');
  });

  test('the shop sells each item once for coins, and puts it on', () {
    final saves = <SavedProgress>[];
    final game = GameState(seed: 1, onSave: saves.add)..restore(const SavedProgress(coins: 300));
    final berry = Shop.skin('berry'), cocoa = Shop.skin('cocoa'), fire = Shop.trail('fire');
    expect(game.owns(Shop.defaultSkin), isTrue, reason: 'the free ones come with the game');
    expect(game.isWearing(Shop.defaultSkin) && game.isWearing(Shop.defaultTrail), isTrue);

    expect(game.buy(fire), isFalse, reason: 'it costs 500');
    expect(game.coins, 300);
    expect(game.trailStyle, Shop.defaultTrail);

    expect(game.buy(berry), isTrue);
    expect(game.coins, 300 - berry.price);
    expect(game.skin, berry, reason: 'a new skin goes straight on');
    expect(saves.last.owned, ['berry']);
    expect(saves.last.skin, 'berry');
    expect(saves.last.coins, 300 - berry.price);

    expect(game.buy(berry), isFalse, reason: 'already owned');
    expect(game.coins, 300 - berry.price);

    game.wear(cocoa);
    expect(game.skin, berry, reason: 'cocoa has not been bought');
    game.wear(Shop.defaultSkin);
    expect(game.skin, Shop.defaultSkin);
    expect(game.coins, 300 - berry.price, reason: 'changing back is free');
  });

  test('restoring the shop ignores items that no longer exist or were never bought', () {
    final game = GameState()
      ..restore(const SavedProgress(owned: ['cocoa', 'retired-hat'], skin: 'cocoa', trail: 'gold'));
    expect(game.owned, {'cocoa'});
    expect(game.skinId, 'cocoa');
    expect(game.trailStyleId, Shop.defaultTrail.id, reason: 'gold was never bought');
    expect(Shop.skins.map((s) => s.id).toSet().length, Shop.skins.length, reason: 'ids are unique');
    expect(Shop.trails.every((t) => t.stripes.length == 6), isTrue);
  });

  test('the climb passes through darker realms, each announced once, and sinks into the Void', () {
    final game = GameState(
        seed: 13,
        tuning: const GameTuning(darkestAtScreen: 5, deepestAtScreen: 8, bonusZoneEvery: 0, hollowChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.realm, 0);
    final entered = <int>[];
    var chimes = 0;
    while (game.mode == GameMode.playing && game.screens < 9) {
      final before = game.realm;
      game.grace = 1;
      _autopilot(game);
      game.update(_frame);
      if (game.realm != before) entered.add(game.realm);
      chimes += game.sounds.where((c) => c.sfx == Sfx.realm).length;
      game.sounds.clear();
      if (game.distance < 5 * GameState.screenLength) expect(game.deep, 0, reason: 'no Void before full darkness');
    }
    expect(entered, [1, 2, 3, 4], reason: 'twilight, starfall, runelight, the Void, in order');
    expect(chimes, 4);
    expect(game.realmCardTime, lessThan(GameState.realmCardSeconds));
    expect(game.deep, 1.0, reason: 'as deep as it goes past screen 8');

    game.pointerMove(GameState.width, game.height * 0.72);
    for (var i = 0; i < 600 && game.mode == GameMode.playing; i++) {
      game.update(_frame);
    }
    expect(game.realm, 4, reason: 'the game-over screen says where the run ended');
    game.pointerUp();
    for (var i = 0; i < 70; i++) {
      game.update(_frame);
    }
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect((game.realm, game.deep), (0, 0.0), reason: 'a new run starts back at the bottom');
  });

  test('memories come back on arrival and from fragments, in story order, and are kept', () {
    final saves = <SavedProgress>[];
    final game = GameState(
        seed: 14,
        onSave: saves.add,
        tuning: const GameTuning(
            darkestAtScreen: 6, bonusZoneEvery: 0, hollowChance: 0, powerUpChance: 0, memoryChance: 1));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.memories, {'sky-0'}, reason: 'the very first run starts with "I woke up flying"');
    expect(game.shownMemory?.id, 'sky-0');
    expect(saves.last.memories, ['sky-0']);

    // the next fragment of the realm drifts in near a wall
    _flyUntil(game, () => game.pickups.any((p) => p.memory != null));
    final fragment = game.pickups.firstWhere((p) => p.memory != null);
    expect(fragment.memory!.id, 'sky-1', reason: 'fragments come in story order');
    expect(game.pickups.where((p) => p.memory != null), hasLength(1), reason: 'one per realm per run');
    final (l, r) = game.wallAt(fragment.wy);
    expect(fragment.x, inInclusiveRange(l, r));
    _flyUntil(game, () => game.shownMemory == null); // "I woke up flying" is shown to the end first
    game.pickups
      ..remove(fragment)
      ..add(Pickup.memory(game.bunnyX, game.worldY(game.bunnyY), fragment.memory!, 0));
    game.update(_frame);
    expect(game.memories, contains('sky-1'));
    expect(game.shownMemory?.id, 'sky-1');
    expect(game.newMemories, isTrue);

    // reaching twilight brings back its arrival memory
    _flyUntil(game, () => game.realm >= 1);
    expect(game.memories, contains('twilight-0'));

    // a new run doesn't repeat what's known, and the save brings everything back
    final again = GameState(seed: 15)..restore(SavedProgress(memories: [...saves.last.memories, 'cut-scene']));
    expect(again.memories, saves.last.memories.toSet(), reason: 'unknown ids are ignored');
    again.pointerDown(GameState.width / 2, again.height * 0.72);
    expect(again.shownMemory, isNull, reason: '"I woke up flying" is only told once');
  });

  test('in the app a memory pauses the run until the player has read it and continues', () {
    final game = GameState(seed: 16, tuning: const GameTuning(bonusZoneEvery: 0, hollowChance: 0))
      ..pauseForMemories = true;
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.readingMemory, isTrue, reason: 'the first run opens on "I woke up flying"');
    expect(game.holding, isFalse, reason: 'the bunny waits where it is');

    final distance = game.distance;
    for (var i = 0; i < 20; i++) {
      game.update(_frame);
    }
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.readingMemory, isTrue, reason: 'a press in the first moment is ignored');
    for (var i = 0; i < 60; i++) {
      game.update(_frame);
    }
    expect(game.distance, distance, reason: 'nothing moves while the memory is shown');
    expect(game.memoryTyped, isFalse);

    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.memoryTyped, isTrue, reason: 'the first press finishes the words');
    expect(game.readingMemory, isTrue);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.readingMemory, isTrue, reason: 'the ink draws back into the bunny first');
    for (var i = 0; i < 40; i++) {
      game.update(_frame);
    }
    expect(game.readingMemory, isFalse, reason: 'then the run goes on');
    expect(game.holding, isFalse, reason: 'that press does not steer; the next hold will');
    expect(game.grace, greaterThan(1), reason: 'a moment to get going again');

    for (var i = 0; i < 60; i++) {
      game.update(_frame);
    }
    expect(game.distance, greaterThan(distance));
    expect(game.mode, GameMode.playing);
  });

  test('memories that come back together wait their turn', () {
    final game = GameState(seed: 17, tuning: const GameTuning(memoryChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    game.pickups.add(Pickup.memory(game.bunnyX, game.worldY(game.bunnyY), Memories.fragmentsOf(0).first, 0));
    game.update(_frame);
    expect(game.memories, contains('sky-1'), reason: 'remembered (and saved) straight away');
    expect(game.shownMemory?.id, 'sky-0', reason: 'but shown after the one already showing');
    _flyUntil(game, () => game.shownMemory?.id != 'sky-0');
    expect(game.shownMemory?.id, 'sky-1');
  });

  test('the story fits: every realm has an arrival and three fragments, in letters the font has', () {
    expect(Memories.all.map((m) => m.id).toSet(), hasLength(Memories.all.length), reason: 'ids are unique');
    for (var realm = 0; realm < GameState.realms.length; realm++) {
      final memories = Memories.ofRealm(realm);
      expect(memories.where((m) => m.arrival), hasLength(1), reason: 'realm $realm');
      expect(Memories.fragmentsOf(realm), hasLength(3), reason: 'realm $realm');
    }
    for (final m in Memories.all) {
      for (final ch in m.text.split('')) {
        expect(ch == ' ' || PixelFont.glyph(ch) != null, isTrue, reason: '"$ch" in ${m.id}');
      }
      final lines = PixelFont.wrap(m.text, 26);
      expect(lines.length, lessThanOrEqualTo(4), reason: '${m.id} fits its strip of paper');
      expect(lines.every((l) => l.length <= 26), isTrue, reason: m.id);
    }
  });

  test('every font glyph is 5x7 and the title letters exist', () {
    for (final ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?&':.,-+going".split('')) {
      expect(PixelFont.glyph(ch)?.length, 35, reason: 'glyph "$ch"');
    }
  });
}
