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
const _m = GameState.unitsPerMeter;

/// Steers for the middle of the gap a little ahead of the bunny.
void _autopilot(GameState game) {
  final (l, r) = game.wallAt(game.distance + game.height - (game.bunnyY - 60));
  game.pointerMove((l + r) / 2, game.height * 0.72);
}

/// Flies into the right wall until the run ends (or 10 seconds pass).
void _crash(GameState game) {
  game.pointerMove(GameState.width, game.height * 0.72);
  for (var i = 0; i < 60 * 10 && game.mode == GameMode.playing; i++) {
    game.update(_frame);
  }
}

/// A new run, after the game-over screen has had its moment.
void _retry(GameState game) {
  game.pointerUp();
  for (var i = 0; i < 70; i++) {
    game.update(_frame);
  }
  game.pointerDown(GameState.width / 2, game.height * 0.72);
}

/// Wearing [skin] and [trail], as if bought.
GameState _wearing({String? skin, String? trail, int seed = 1, GameTuning tuning = const GameTuning()}) =>
    GameState(seed: seed, tuning: tuning)
      ..restore(SavedProgress(owned: [?skin, ?trail], skin: skin, trail: trail));

void main() {
  test('the bunny is half a meter long, and meters are counted as the run climbs', () {
    expect(GameState.bunnyLength / GameState.unitsPerMeter, 0.5);
    final game = GameState(seed: 1);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    _flyUntil(game, () => game.distance >= 42 * _m);
    expect(game.meters, 42);
    _crash(game);
    expect(game.lastMeters, game.meters);
    expect(game.best, game.meters);
  });

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
    // past the point where difficulty tops out and still flying
    expect(game.meters, greaterThan(const GameTuning().hardestAtMeters));
  });

  test('two players given the same seed fly the same tunnel, whatever their speed or screen', () {
    Map<double, (double, double)> fly(GameState game, double height) {
      game
        ..height = height
        ..runSeed = 77;
      game.pointerDown(GameState.width / 2, game.height * 0.72);
      final seen = <double, (double, double)>{};
      _flyUntil(game, () {
        for (final s in game.walls) {
          seen[s.wy] = (s.left, s.right);
        }
        return game.meters >= 300;
      });
      return seen;
    }

    final slow = fly(GameState(seed: 1), GameState.minHeight);
    final fast = fly(_wearing(skin: 'comet', seed: 2), GameState.maxHeight);
    final both = slow.keys.where(fast.containsKey).toList();
    expect(both.length, greaterThan(3000), reason: 'both flew 300 meters');
    for (final wy in both) {
      expect(fast[wy], slow[wy], reason: 'wall at $wy');
    }
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
    _crash(game);
    expect(game.mode, GameMode.dead);
    expect(saved?.crashY, isNotNull);
    expect(saved?.lastMeters, game.meters);

    game.pointerUp();
    for (var i = 0; i < 60; i++) {
      game.update(_frame);
    }
    expect(game.canRetry, isTrue);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.mode, GameMode.playing);
    expect(game.marker?.wy, closeTo(saved!.crashY!, 1e-9));
  });

  test('restore brings back the best run and crash point', () {
    final game = GameState(seed: 4)..restore(const SavedProgress(best: 120, crashY: 900, crashX: 80));
    expect(game.best, 120);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.marker?.x, 80);
  });

  test('bonus zones open wide every N meters, with coins, and keep clear of memory forks', () {
    const every = 20;
    final game =
        GameState(seed: 5, tuning: const GameTuning(bonusZoneEveryMeters: every, openSectionChance: 0, powerUpChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    final wide = <double>{};
    var coinsSeen = 0;
    while (game.mode == GameMode.playing && game.meters < 120) {
      _autopilot(game);
      game.update(_frame);
      for (final s in game.walls) {
        if (s.wy > 1000 && s.right - s.left >= 345) wide.add(s.wy); // wider than a memory fork
      }
      coinsSeen = math.max(coinsSeen, game.pickups.where((p) => p.isCoin).length);
    }
    expect(game.meters, greaterThanOrEqualTo(120));
    // group the wide samples into zones
    final sorted = wide.toList()..sort();
    final starts = [sorted.first, for (var i = 1; i < sorted.length; i++) if (sorted[i] - sorted[i - 1] > 400) sorted[i]];
    expect(starts.length, greaterThanOrEqualTo(3), reason: 'zone after zone');
    expect(starts.first, greaterThan(30 * _m), reason: 'the first one waits until the first memory fork has passed');
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], closeTo(every * _m, 0.2 * every * _m), reason: 'then every $every meters');
    }
    expect(coinsSeen, greaterThan(15));
    expect(game.coins, greaterThan(0), reason: 'the autopilot flies through the coin snake');
  });

  test('walls still open up wide late in a fast run', () {
    // ordinary tunnel at full difficulty is never wider than about 210
    final game = GameState(
        seed: 6,
        tuning: const GameTuning(bonusZoneEveryMeters: 0, powerUpChance: 0, openSectionChance: 0.3, hollowChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    var lateWide = false;
    while (game.mode == GameMode.playing && game.meters < 380) {
      _autopilot(game);
      game.update(_frame);
      if (game.meters > 300) lateWide = lateWide || game.walls.any((s) => s.right - s.left >= 285);
    }
    expect(game.meters, greaterThanOrEqualTo(380));
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
    final game =
        GameState(seed: 9, tuning: const GameTuning(powerUpChance: 0, bonusZoneEveryMeters: 0, openSectionChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.sounds.map((c) => c.sfx), [Sfx.takeoff], reason: 'no memory interrupts the take-off');
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

    _crash(game);
    expect(game.mode, GameMode.dead);
    expect(game.sounds.last.sfx, Sfx.crash);
  });

  test('the shield takes a hit, halves the level speed, then catches up in a quarter of the time', () {
    final game =
        GameState(seed: 8, tuning: const GameTuning(shieldHitSlowSeconds: 2, powerUpChance: 0, bonusZoneEveryMeters: 0));
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

  test('the run darkens as you climb, fully on reaching the Void, and a new run starts bright', () {
    final game =
        GameState(seed: 12, tuning: const GameTuning(realmEveryMeters: 6, bonusZoneEveryMeters: 0, hollowChance: 0));
    expect(game.mood, 0, reason: 'the title screen is bright');
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    final moods = <double>[];
    while (game.mode == GameMode.playing && game.meters < 26) {
      _autopilot(game);
      game.update(_frame);
      moods.add(game.mood);
      if (game.distance < 6 * _m) expect(game.realm, 0);
    }
    expect(game.meters, greaterThanOrEqualTo(26));
    for (var i = 1; i < moods.length; i++) {
      expect(moods[i], greaterThanOrEqualTo(moods[i - 1]), reason: 'it only gets darker during a run');
    }
    expect(moods.firstWhere((m) => m > 0.45), lessThan(0.6));
    expect(game.mood, 1.0, reason: 'full night in the Void, 4 x 6 meters up');

    _crash(game);
    expect(game.mode, GameMode.dead);
    expect(game.mood, 1.0, reason: 'the game-over screen keeps the mood of the crash');
    _retry(game);
    expect(game.mood, 0, reason: 'a new run starts bright');
  });

  test('realms are evenly spaced in meters, and each starts at its own darkness', () {
    final game = GameState(seed: 12);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    final every = const GameTuning().realmEveryMeters;
    for (var r = 0; r < GameState.realms.length; r++) {
      expect(game.realmStart(r), r * every * _m);
      game.distance = game.realmStart(r);
      expect(game.mood, closeTo(GameState.realms[r].from, 1e-9), reason: GameState.realms[r].name);
    }
    game.distance = 2.5 * every * _m;
    expect(game.mood, closeTo((GameState.realms[2].from + GameState.realms[3].from) / 2, 1e-9));
  });

  test('hollows only wait in open space, from Ashfall on, and always leave a way past', () {
    final game = GameState(seed: 21);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    int? firstMeters;
    final seen = <Hollow>{};
    var warned = false;
    var checked = 0;
    while (game.mode == GameMode.playing && game.meters < 460) {
      game.grace = 1; // fly straight through everything: this test only looks at the layout
      _autopilot(game);
      game.update(_frame);
      warned = warned || game.toast == 'THEY FOUND YOU.';
      for (final g in game.hollows) {
        if (seen.add(g)) firstMeters ??= game.meters;
        final sy = game.screenY(g.wy);
        if (sy < 0 || sy > game.height) continue; // walls are only known around the screen
        final (l, r) = game.wallAt(g.wy);
        checked++;
        expect(r - l, greaterThanOrEqualTo(250), reason: 'never in a narrow corridor');
        expect(g.x - Hollow.radius, greaterThanOrEqualTo(l), reason: 'clear of the left wall');
        expect(g.x + Hollow.radius, lessThanOrEqualTo(r), reason: 'clear of the right wall');
        final room = math.max(g.x - Hollow.radius - l, r - g.x - Hollow.radius);
        expect(room, greaterThanOrEqualTo(56), reason: 'one side always has room for the bunny');
      }
    }
    expect(game.meters, 460);
    expect(firstMeters, isNotNull);
    final ashfall = const GameTuning().hollowsFromRealm * const GameTuning().realmEveryMeters;
    expect(firstMeters, greaterThanOrEqualTo(ashfall - 25),
        reason: 'hollows are planned a little ahead of where they appear');
    expect(seen.length, greaterThan(4));
    expect(checked, greaterThan(100));
    expect(warned, isTrue, reason: 'the first hollow of a run comes with a warning');
  });

  test('a Hollow One ends the run, the shield pops one, and they hop with a warning', () {
    final game =
        GameState(seed: 22, tuning: const GameTuning(powerUpChance: 0, bonusZoneEveryMeters: 0, hollowChance: 0));
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
    for (final shelf in [Shop.skins, Shop.trails]) {
      expect(shelf.map((s) => s.id).toSet().length, shelf.length, reason: 'ids are unique');
      expect(shelf.first.price, 0, reason: 'the first one is free');
      for (var i = 1; i < shelf.length; i++) {
        expect(shelf[i].price, greaterThan(shelf[i - 1].price), reason: 'cheapest first');
      }
    }
    expect(Shop.trails.every((t) => t.stripes.length == 6), isTrue);
  });

  test('only the items dearer than 2000 coins have perks, each a different one, described in the font', () {
    final items = [...Shop.skins, ...Shop.trails];
    expect(items.length, greaterThanOrEqualTo(26));
    for (final item in items) {
      expect(item.perk != Perk.none, item.price > Shop.perksAbove, reason: item.name);
    }
    final perks = items.map((i) => i.perk).where((p) => p != Perk.none).toList();
    expect(perks.toSet(), Perk.values.toSet()..remove(Perk.none), reason: 'every perk is for sale once');
    expect(perks, hasLength(Perk.values.length - 1));
    for (final perk in perks) {
      expect(perk.description.split('').every((ch) => ch == ' ' || PixelFont.glyph(ch) != null), isTrue,
          reason: perk.description);
      expect(PixelFont.widthOf(perk.description, 2), lessThan(330), reason: 'fits the shop preview');
    }
  });

  test('the comet skin starts the run half again as fast', () {
    final plain = GameState(seed: 30)..pointerDown(GameState.width / 2, 400);
    final comet = _wearing(skin: 'comet', seed: 30)..pointerDown(GameState.width / 2, 400);
    expect(comet.baseSpeed, closeTo(plain.baseSpeed * 1.5, 0.01));
    for (var i = 0; i < 120; i++) {
      plain.update(_frame);
      comet.update(_frame);
    }
    expect(comet.distance, greaterThan(plain.distance * 1.4));
  });

  test('the guardian skin starts every run with a shield', () {
    final game = _wearing(skin: 'guardian', seed: 31);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.shield, isTrue);
    for (var i = 0; i < 90; i++) {
      game.update(_frame);
    }
    _crash(game);
    expect(game.mode, GameMode.dead, reason: 'one hit is soaked up, the next one is not');
    _retry(game);
    expect(game.shield, isTrue, reason: 'and the next run has a new one');
  });

  test('the phantom skin lets the Hollow Ones pass through', () {
    final game = _wearing(skin: 'phantom', seed: 32);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    for (var i = 0; i < 90; i++) {
      _autopilot(game);
      game.update(_frame);
    }
    game.hollows.add(Hollow(game.worldY(game.bunnyY), game.bunnyX, 0, 0, 0));
    for (var i = 0; i < 10; i++) {
      game.update(_frame);
    }
    expect(game.mode, GameMode.playing);
  });

  test('the magnet trail pulls in nearby coins, and the lucky trail counts each one twice', () {
    int collect(GameState game) {
      game.pointerDown(GameState.width / 2, game.height * 0.72);
      game.update(_frame);
      game.pickups.add(Pickup.coin(game.bunnyX + 75, game.worldY(game.bunnyY) + 20, 0));
      for (var i = 0; i < 30; i++) {
        game.grace = 1;
        game.update(_frame);
      }
      return game.runCoins;
    }

    expect(collect(GameState(seed: 33)), 0, reason: 'out of reach');
    expect(collect(_wearing(trail: 'magnet', seed: 33)), 1, reason: 'pulled in');
    final lucky = _wearing(trail: 'lucky', seed: 33)..pointerDown(GameState.width / 2, 400);
    lucky.pickups.add(Pickup.coin(lucky.bunnyX, lucky.worldY(lucky.bunnyY), 0));
    lucky.update(_frame);
    expect((lucky.runCoins, lucky.coins), (2, 2));
  });

  test('the phoenix trail forgives one crash a run', () {
    final game = _wearing(trail: 'phoenix', seed: 34);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    for (var i = 0; i < 90; i++) {
      game.update(_frame);
    }
    game.pointerMove(GameState.width, game.height * 0.72);
    var forgiven = false;
    for (var i = 0; i < 60 * 10 && game.mode == GameMode.playing; i++) {
      game.update(_frame);
      forgiven = forgiven || (game.toast == 'SECOND CHANCE!' && game.toastTime > 0);
    }
    expect(forgiven, isTrue);
    expect(game.mode, GameMode.dead, reason: 'the second crash is not');
    _retry(game);
    expect(game.spareLife, isTrue, reason: 'a new run, a new chance');
  });

  test('nothing is remembered on its own: no memory at take-off or on entering a realm', () {
    final game = GameState(seed: 14, tuning: const GameTuning(realmEveryMeters: 10, hollowChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.shownMemory, isNull);
    _flyUntil(game, () => game.realm >= 1);
    expect(game.realm, 1);
    expect(game.memories, isEmpty);
    expect(game.shownMemory, isNull);
  });

  test("each realm's memory and its next fragment wait side by side: take one and the other is lost", () {
    final saves = <SavedProgress>[];
    final game = GameState(seed: 14, onSave: saves.add, tuning: const GameTuning(hollowChance: 0));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    _flyUntil(game, () => game.pickups.any((p) => p.memory != null));
    final choice = game.pickups.where((p) => p.memory != null).toList();
    expect(choice.map((p) => p.memory!.id).toSet(), {'sky-0', 'sky-1'}, reason: 'the memory and the first fragment');
    expect(choice.map((p) => p.group).toSet(), hasLength(1), reason: 'one choice');
    expect(choice[0].wy, choice[1].wy, reason: 'side by side');
    expect((choice[0].x - choice[1].x).abs(), greaterThan(150), reason: 'far enough apart to pick one');
    expect(choice.singleWhere((p) => p.isRealmMemory).memory!.arrival, isTrue);
    expect(choice.first.wy, inInclusiveRange(20 * _m, 40 * _m), reason: 'early in the first realm');

    // the tunnel opens wide around them
    _flyUntil(game, () => game.screenY(choice.first.wy) > 100);
    final (l, r) = game.wallAt(choice.first.wy);
    expect(r - l, greaterThan(300));
    for (final p in choice) {
      expect(p.x, inInclusiveRange(l + 20, r - 20));
    }

    final fragment = choice.singleWhere((p) => !p.isRealmMemory);
    fragment
      ..x = game.bunnyX
      ..wy = game.worldY(game.bunnyY);
    game.update(_frame);
    expect(game.memories, {'sky-1'});
    expect(game.shownMemory?.id, 'sky-1');
    expect(game.newMemories, isTrue);
    expect(game.pickups.where((p) => p.memory != null), isEmpty, reason: 'the memory was given up');
    expect(saves.last.memories, ['sky-1']);

    // the next run offers the memory again, with the next fragment
    final again = GameState(seed: 15, tuning: const GameTuning(hollowChance: 0))
      ..restore(SavedProgress(memories: [...saves.last.memories, 'cut-scene']));
    expect(again.memories, {'sky-1'}, reason: 'unknown ids are ignored');
    again.pointerDown(GameState.width / 2, again.height * 0.72);
    _flyUntil(again, () => again.pickups.any((p) => p.memory != null));
    expect(again.pickups.where((p) => p.memory != null).map((p) => p.memory!.id).toSet(), {'sky-0', 'sky-2'});

    // once a realm has nothing left to give, its fork stands empty
    final done = GameState(seed: 16, tuning: const GameTuning(hollowChance: 0))
      ..restore(SavedProgress(memories: [for (final m in Memories.ofRealm(0)) m.id]));
    done.pointerDown(GameState.width / 2, done.height * 0.72);
    var offered = false;
    _flyUntil(done, () {
      offered = offered || done.pickups.any((p) => p.memory != null);
      return done.meters >= 40;
    });
    expect(offered, isFalse);
  });

  test('a lone memory is in the middle, and the last fragment of a realm comes with no choice', () {
    final game = GameState(seed: 17, tuning: const GameTuning(hollowChance: 0))
      ..restore(const SavedProgress(memories: ['sky-0', 'sky-1', 'sky-2']));
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    _flyUntil(game, () => game.pickups.any((p) => p.memory != null));
    final only = game.pickups.singleWhere((p) => p.memory != null);
    expect(only.memory!.id, 'sky-3');
    expect(only.x, GameState.width / 2);
  });

  test('in the app a memory pauses the run until the player has read it and continues', () {
    final game = GameState(seed: 16, tuning: const GameTuning(bonusZoneEveryMeters: 0, hollowChance: 0))
      ..pauseForMemories = true;
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    expect(game.readingMemory, isFalse, reason: 'the run starts straight away');
    game.update(_frame);
    game.pickups.add(Pickup.memory(game.bunnyX, game.worldY(game.bunnyY), Memories.arrivalOf(0), 0));
    game.update(_frame);
    expect(game.readingMemory, isTrue);
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
    final game = GameState(seed: 17);
    game.pointerDown(GameState.width / 2, game.height * 0.72);
    game.update(_frame);
    for (final m in [Memories.arrivalOf(0), Memories.fragmentsOf(0).first]) {
      game.pickups.add(Pickup.memory(game.bunnyX, game.worldY(game.bunnyY), m, 0));
    }
    game.update(_frame);
    expect(game.memories, {'sky-0', 'sky-1'}, reason: 'remembered (and saved) straight away');
    expect(game.shownMemory?.id, 'sky-0', reason: 'but shown one after the other');
    _flyUntil(game, () => game.shownMemory?.id != 'sky-0');
    expect(game.shownMemory?.id, 'sky-1');
  });

  test('the story fits: every realm has its memory and three fragments, in letters the font has', () {
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
    for (final ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?&':.,-+%/going".split('')) {
      expect(PixelFont.glyph(ch)?.length, 35, reason: 'glyph "$ch"');
    }
  });
}
