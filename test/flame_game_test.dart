import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/pickups.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';

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
      expect(game.state.mode, GameMode.title, reason: 'pressing the button does not start a run');
      expect(reported, [true]);

      expect(game.press(Vector2(GameState.width / 2, game.state.height / 2), touch: true), isTrue);
      expect(game.state.mode, GameMode.playing);
    },
  );

  testWithGame<GoingUpGame>(
    'the picture eases toward the run\'s mood instead of jumping',
    () => GoingUpGame(state: GameState(seed: 4, tuning: const GameTuning(darkestAtScreen: 1, bonusZoneEvery: 0))),
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
