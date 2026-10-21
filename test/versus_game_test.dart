import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/versus_screen.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';
import 'package:goingup/game/versus/lan.dart';
import 'package:goingup/game/versus/match.dart';

/// Two whole games on a pretend network, driven through their buttons like two players would.
void main() {
  late GoingUpGame host, guest;

  setUp(() async {
    final network = MemoryNetwork();
    host = await initializeGame(() => GoingUpGame(state: GameState(seed: 1), lan: network.lan()));
    guest = await initializeGame(
        () => GoingUpGame(state: GameState(seed: 2)..restore(const SavedProgress(owned: ['ember'], skin: 'ember')), lan: network.lan()));
  });

  tearDown(() {
    host.onRemove();
    guest.onRemove();
  });

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      host.update(1 / 60);
      guest.update(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }
  }

  void draw(GoingUpGame game) {
    final recorder = PictureRecorder();
    game.render(Canvas(recorder));
    recorder.endRecording().dispose();
  }

  void press(GoingUpGame game, Rect rect) => game.press(Vector2(rect.center.dx, rect.center.dy), touch: true);

  VersusButton button(GoingUpGame game, String label) =>
      game.versusScreen.buttons.firstWhere((b) => b.label == label, orElse: () => throw StateError('no $label'));

  Future<void> intoLobby() async {
    press(host, host.versusButton);
    press(host, button(host, 'HOST A GAME').rect);
    press(guest, guest.versusButton);
    press(guest, button(guest, 'JOIN A GAME').rect);
    await frames(3);
    final found = guest.versusScreen.buttons.where((b) => b.game != null).toList();
    expect(found, hasLength(1), reason: "the host's game is heard");
    expect(found.single.game!.skin, Shop.defaultSkin.id);
    draw(guest);
    press(guest, found.single.rect);
    await frames(3);
    expect(host.versusScreen.page, VersusPage.lobby);
    expect(guest.versusScreen.page, VersusPage.lobby);
    expect(host.match?.friendSkin, 'ember');
  }

  test('two players find each other, race the same tunnel, and see who won', () async {
    expect(host.showsVersusButton, isTrue);
    await intoLobby();
    draw(host);
    draw(guest);
    expect(() => button(guest, 'START'), throwsStateError, reason: 'only the host starts the race');

    press(host, button(host, 'START').rect);
    await frames(3);
    expect(host.versusScreen.isOpen || guest.versusScreen.isOpen, isFalse, reason: 'the countdown shows over the tunnel');
    expect(host.match!.phase, MatchPhase.countdown);
    draw(host);
    await frames(200);
    expect(host.state.mode, GameMode.playing);
    expect(guest.state.mode, GameMode.playing);
    expect(host.showsShopButton || host.showsVersusButton, isFalse);

    // both hold and fly for a while; the host's ghost is drawn on the guest's screen
    host.press(Vector2(GameState.width / 2, host.state.height * 0.72), touch: true);
    guest.press(Vector2(GameState.width / 2, guest.state.height * 0.72), touch: true);
    for (var i = 0; i < 90; i++) {
      for (final g in [host, guest]) {
        g.state.grace = 1;
        final (l, r) = g.state.wallAt(g.state.distance + g.state.height - (g.state.bunnyY - 60));
        g.state.pointerMove((l + r) / 2, g.state.height * 0.72);
      }
      await frames(1);
    }
    expect(guest.match!.ghostVisible, isTrue);
    draw(guest);

    // the guest flies into a wall
    guest.state
      ..grace = 0
      ..pointerMove(GameState.width, guest.state.height * 0.72);
    for (var i = 0; i < 600 && !(host.state.showGameOver && guest.state.showGameOver && guest.match?.result != null); i++) {
      host.state.grace = 1;
      await frames(1);
    }
    expect(host.match!.result, MatchResult.won);
    expect(guest.match!.result, MatchResult.lost);
    expect(host.showsRematchButton && guest.showsRematchButton, isTrue);
    draw(host);
    draw(guest);

    // the guest asks for a rematch, then leaves instead
    press(guest, guest.rematchButton);
    await frames(2);
    expect(host.match!.friendReady, isTrue);
    draw(host);
    press(guest, guest.leaveButton);
    await frames(2);
    expect(guest.match, isNull);
    expect(guest.state.mode, GameMode.title);
    expect(guest.state.versus, isFalse);
    expect(host.match!.friendLeft, isTrue);
    expect(host.showsRematchButton, isFalse, reason: 'nobody to race');
    expect(host.showsMatchButtons, isTrue);
    press(host, host.leaveButton);
    await frames(2);
    expect(host.state.mode, GameMode.title);
    expect(host.showsVersusButton, isTrue);
  });

  test('a friend leaving the lobby says so, and the screens find their way back', () async {
    await intoLobby();
    press(guest, button(guest, 'LEAVE').rect);
    await frames(3);
    expect(guest.versusScreen.page, VersusPage.menu);
    expect(host.versusScreen.page, VersusPage.message);
    expect(host.match, isNull);
    draw(host);
    press(host, button(host, 'OK').rect);
    expect(host.versusScreen.page, VersusPage.menu);
    press(host, button(host, 'BACK').rect);
    expect(host.versusScreen.isOpen, isFalse);
  });

  test('an address can be typed on the keypad', () async {
    press(guest, guest.versusButton);
    press(guest, button(guest, 'JOIN A GAME').rect);
    press(guest, button(guest, 'TYPE AN ADDRESS').rect);
    for (final key in '10.0.0.9'.split('')) {
      press(guest, button(guest, key).rect);
    }
    expect(guest.versusScreen.typed, '10.0.0.9');
    press(guest, button(guest, 'DEL').rect);
    press(guest, button(guest, '1').rect);
    expect(guest.versusScreen.typed, '10.0.0.1');
    draw(guest);
    press(guest, button(guest, 'JOIN').rect);
    await frames(3);
    expect(guest.versusScreen.page, VersusPage.message, reason: 'nobody is hosting there');
    draw(guest);
  });
}
