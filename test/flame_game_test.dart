import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/bunny.dart';
import 'package:goingup/game/components/pickups.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';
import 'package:goingup/game/sfx.dart';

PickupLayer _pickupLayer(GoingUpGame game) => game.world.children.whereType<PickupLayer>().single;

void main() {
  testWithGame<GoingUpGame>(
    'pickups in the state appear as components and disappear when taken',
    () => GoingUpGame(state: GameState(seed: 1, tuning: const GameTuning(powerUpChance: 0, openSectionChance: 0))),
    (game) async {
      final state = game.state;
      state.pointerDown(GameState.width / 2, state.height * 0.72);
      state.pickups.add(Pickup.coin(150, state.distance + 300, 0));
      game.update(1 / 60);
      await game.ready();
      final layer = _pickupLayer(game);
      expect(layer.children.whereType<PickupComponent>().length, state.pickups.length);
      expect(state.pickups, isNotEmpty);

      state.pickups.clear();
      game.update(1 / 60);
      await game.ready();
      expect(layer.children.whereType<PickupComponent>(), isEmpty);
    },
  );

  testWithGame<GoingUpGame>(
    'the field follows the screen shape, from phone to wide window',
    GoingUpGame.new,
    (game) async {
      game.onGameResize(Vector2(390, 844)); // a tall phone
      await game.ready();
      expect(game.state.height, closeTo(GameState.width * 844 / 390, 0.01));
      final phone = game.camera.viewport as FixedResolutionViewport;
      expect(phone.resolution.y, closeTo(game.state.height, 0.5));

      game.onGameResize(Vector2(1280, 800)); // a wide desktop window gets side bars
      await game.ready();
      expect(game.state.height, GameState.minHeight);
      final desktop = game.camera.viewport as FixedResolutionViewport;
      expect(desktop.resolution.y, closeTo(GameState.minHeight, 0.5));
      expect(desktop.size.y, closeTo(800, 0.5));
      expect(desktop.size.x, closeTo(800 * GameState.width / GameState.minHeight, 0.5));
    },
  );

  testWithGame<GoingUpGame>(
    'the speaker button mutes instead of starting a run, and the choice is reported',
    GoingUpGame.new,
    (game) async {
      final reported = <bool>[];
      game.onMuteChanged = reported.add;
      final button = game.muteButton.center;
      expect(game.press(Vector2(button.dx, button.dy), touch: true), isFalse);
      expect(game.music.muted, isTrue);
      expect(game.sfx.muted, isTrue, reason: 'the sound effects go quiet too');
      expect(game.state.mode, GameMode.title, reason: 'pressing the button does not start a run');
      expect(reported, [true]);

      expect(game.press(Vector2(GameState.width / 2, game.state.height / 2), touch: true), isTrue);
      expect(game.state.mode, GameMode.playing);
    },
  );

  testWithGame<GoingUpGame>(
    'the picture eases toward the run\'s mood instead of jumping',
    () => GoingUpGame(state: GameState(seed: 4, tuning: const GameTuning(realmEveryMeters: 2, bonusZoneEveryMeters: 0, hollowChance: 0))),
    (game) async {
      final state = game.state;
      game.press(Vector2(GameState.width / 2, state.height * 0.72), touch: false);
      for (var i = 0; i < 60 * 6 && state.mode == GameMode.playing; i++) {
        final (l, r) = state.wallAt(state.distance + state.height - (state.bunnyY - 60));
        state.pointerMove((l + r) / 2, state.height * 0.72);
        game.update(1 / 60);
      }
      expect(state.mood, 1.0);
      expect(game.mood, greaterThan(0.95));

      // a fresh run is bright straight away in the rules, and the picture follows within seconds
      state.pointerMove(GameState.width, state.height * 0.72);
      for (var i = 0; i < 60 * 10 && state.mode == GameMode.playing; i++) {
        game.update(1 / 60);
      }
      for (var i = 0; i < 70; i++) {
        game.update(1 / 60);
      }
      state.pointerUp();
      game.press(Vector2(GameState.width / 2, state.height * 0.72), touch: false);
      expect(state.mood, 0);
      game.update(1 / 60);
      expect(game.mood, greaterThan(0.9), reason: 'no sudden flash back to bright');
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      // a second in, the picture is well on its way back to bright, still easing down
      expect(game.mood, lessThan(0.6));
      expect(game.mood, greaterThan(state.mood));
    },
  );

  testWithGame<GoingUpGame>(
    'the shop button opens the shop instead of starting a run, and buying there puts the item on',
    () => GoingUpGame(state: GameState(seed: 1)),
    (game) async {
      final state = game.state..restore(const SavedProgress(coins: 120));
      final sfx = game.sfx as SilentSfx;
      Vector2 at(Offset p) => Vector2(p.dx, p.dy);
      expect(game.showsShopButton, isTrue);
      expect(game.canBuySomething, isTrue, reason: 'berry costs 100');

      expect(game.press(at(game.shopButton.center), touch: true), isFalse);
      expect(game.shop.isOpen, isTrue);
      expect(state.mode, GameMode.title, reason: 'the press did not start a run');
      expect(game.showsShopButton, isFalse);

      expect(game.press(at(game.shop.card(1).center), touch: true), isFalse); // berry
      expect(game.shop.selected.id, 'berry');
      game.press(at(game.shop.actionButton.center), touch: true);
      expect(state.skinId, 'berry');
      expect(state.coins, 20);
      expect(sfx.played.last.sfx, Sfx.buy);
      expect(game.canBuySomething, isFalse);

      game.press(at(game.shop.tab(Shelf.trails).center), touch: true);
      game.press(at(game.shop.card(5).center), touch: true); // gold, far too dear
      game.press(at(game.shop.actionButton.center), touch: true);
      expect(state.trailStyleId, Shop.defaultTrail.id);
      expect(sfx.played.last.sfx, Sfx.nope);

      game.press(at(game.shop.backButton.center), touch: true);
      expect(game.shop.isOpen, isFalse);
      expect(state.mode, GameMode.title);
      expect(game.press(Vector2(GameState.width / 2, state.height * 0.5), touch: true), isTrue);
      expect(state.mode, GameMode.playing);
      game.update(1 / 60);
      await game.ready();
      expect(game.world.children.whereType<BunnyView>().single.isLoaded, isTrue);
    },
  );

  testWithGame<GoingUpGame>(
    'the shop fits the shortest and the tallest field',
    GoingUpGame.new,
    (game) async {
      for (final size in [Vector2(1280, 800), Vector2(390, 844), Vector2(360, 900)]) {
        game.onGameResize(size);
        await game.ready();
        game.shop.open();
        final rects = [
          ...Shelf.values.map(game.shop.tab),
          game.shop.preview,
          for (var i = 0; i < 6; i++) game.shop.card(i),
          game.shop.actionButton,
          game.shop.backButton,
        ];
        for (final r in rects) {
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(GameState.width));
          expect(r.top, greaterThanOrEqualTo(game.safeTop));
          expect(r.bottom, lessThanOrEqualTo(game.state.height - game.safeBottom));
        }
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse, reason: 'shop areas $i and $j overlap at $size');
          }
        }
        expect(game.shop.backButton.overlaps(game.muteButton), isFalse);
        game.shop.close();
      }
    },
  );

  testWithGame<GoingUpGame>(
    'the memories book opens from the title, turns its pages and closes',
    () => GoingUpGame(state: GameState(seed: 1)),
    (game) async {
      final state = game.state..restore(const SavedProgress(memories: ['sky-0', 'sky-2', 'twilight-0']));
      state.newMemories = true;
      Vector2 at(Offset p) => Vector2(p.dx, p.dy);
      expect(game.showsMemoriesButton, isTrue);
      expect(game.press(at(game.memoriesButton.center), touch: true), isFalse);
      expect(game.book.isOpen, isTrue);
      expect(state.mode, GameMode.title, reason: 'the press did not start a run');
      expect(state.newMemories, isFalse, reason: 'opening the book reads them');
      expect(game.book.page, 1, reason: 'opens at the deepest page with something on it');
      expect(game.showsShopButton || game.showsMemoriesButton, isFalse);

      game.press(at(game.book.previousButton.center), touch: true);
      expect(game.book.page, 0);
      game.press(at(game.book.previousButton.center), touch: true);
      expect(game.book.page, 0, reason: 'no page before the first');
      for (var i = 0; i < 6; i++) {
        game.press(at(game.book.nextButton.center), touch: true);
      }
      expect(game.book.page, GameState.realms.length - 1);

      game.press(at(game.book.backButton.center), touch: true);
      expect(game.book.isOpen, isFalse);
      expect(game.press(Vector2(GameState.width / 2, state.height * 0.4), touch: true), isTrue);
      expect(state.mode, GameMode.playing);
    },
  );

  testWithGame<GoingUpGame>(
    'the memories book fits the shortest and the tallest field, with every memory found',
    () => GoingUpGame(state: GameState()..restore(SavedProgress(memories: [for (final m in Memories.all) m.id]))),
    (game) async {
      for (final size in [Vector2(1280, 800), Vector2(390, 844), Vector2(360, 900)]) {
        game.onGameResize(size);
        await game.ready();
        game.book.open();
        for (var page = 0; page < GameState.realms.length; page++) {
          game.book.page = page;
          final rects = [game.book.previousButton, game.book.nextButton, ...game.book.entries, game.book.backButton];
          for (final r in rects) {
            expect(r.top, greaterThanOrEqualTo(game.safeTop));
            expect(r.bottom, lessThanOrEqualTo(game.state.height - game.safeBottom));
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse, reason: 'page $page: areas $i and $j overlap at $size');
            }
          }
        }
        game.book.close();
      }
      expect(game.memoriesButton.overlaps(game.muteButton) || game.memoriesButton.overlaps(game.shopButton), isFalse);
    },
  );

  testWithGame<GoingUpGame>(
    'the deepest, most broken realm draws without trouble',
    () => GoingUpGame(
        state: GameState(seed: 9, tuning: const GameTuning(realmEveryMeters: 2, voidDeepensOverMeters: 3, bonusZoneEveryMeters: 0))),
    (game) async {
      final state = game.state;
      game.press(Vector2(GameState.width / 2, state.height * 0.72), touch: false);
      for (var i = 0; i < 60 * 12 && state.deep < 1; i++) {
        state.grace = 1;
        final (l, r) = state.wallAt(state.distance + state.height - (state.bunnyY - 60));
        state.pointerMove((l + r) / 2, state.height * 0.72);
        game.update(1 / 60);
      }
      for (var i = 0; i < 120; i++) {
        state.grace = 1;
        game.update(1 / 60);
      }
      expect(state.deep, 1.0);
      expect(game.corruption, greaterThan(0.95));
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        final recorder = PictureRecorder();
        game.render(Canvas(recorder));
        recorder.endRecording().dispose();
      }
    },
  );

  testWithGame<GoingUpGame>(
    'the game plays the sounds the rules ask for',
    () => GoingUpGame(state: GameState(seed: 2)),
    (game) async {
      final sfx = game.sfx as SilentSfx;
      game.press(Vector2(GameState.width / 2, game.state.height * 0.72), touch: false);
      game.update(1 / 60);
      expect(sfx.played.map((c) => c.sfx), [Sfx.takeoff]);
      expect(game.state.sounds, isEmpty, reason: 'the game empties the list');
    },
  );

  testWithGame<GoingUpGame>(
    'a crash becomes a particle burst in the world',
    () => GoingUpGame(state: GameState(seed: 3)),
    (game) async {
      final state = game.state;
      state.pointerDown(GameState.width / 2, state.height * 0.72);
      state.pointerMove(GameState.width, state.height * 0.72); // hug the right wall
      for (var i = 0; i < 60 * 10 && state.mode == GameMode.playing; i++) {
        game.update(1 / 60);
      }
      await game.ready();
      expect(state.mode, GameMode.dead);
      expect(state.bursts, isEmpty, reason: 'the game turns bursts into particle systems');
      expect(game.world.children.whereType<ParticleSystemComponent>(), isNotEmpty);
    },
  );
}
