@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/components/versus_screen.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/going_up_game.dart';
import 'package:goingup/game/versus/lan.dart';
import 'package:goingup/game/versus/match.dart';

/// The real sockets, on this computer.
void main() {
  test('a hosted game takes a friend over TCP, and messages go both ways', () async {
    final lan = createLan();
    expect(lan.supported, isTrue);
    final host = await lan.host('comet');
    addTearDown(host.close);
    final joined = host.joins.first;
    final guest = await lan.join('127.0.0.1', port: host.port);
    final friend = await joined.timeout(const Duration(seconds: 5));

    final atHost = friend.messages.first;
    guest.send({'t': 'hello', 'skin': 'comet'});
    expect(await atHost.timeout(const Duration(seconds: 5)), {'t': 'hello', 'skin': 'comet'});

    final atGuest = <Map<String, Object?>>[];
    final guestDone = Completer<void>();
    guest.messages.listen(atGuest.add, onDone: guestDone.complete);
    friend.send({'t': 's', 'x': 120.5, 'wy': 9000.0, 'm': 81, 'sh': true});
    friend.send({'t': 'bye'});
    await friend.close();
    await guestDone.future.timeout(const Duration(seconds: 5));
    expect(atGuest.map((m) => m['t']), ['s', 'bye'], reason: 'everything sent before closing arrives');
    expect(atGuest.first['m'], 81);
    await guest.close();
  });

  test('joining where nobody is hosting fails instead of hanging', () async {
    await expectLater(createLan().join('127.0.0.1', port: 9).timeout(const Duration(seconds: 10)), throwsA(anything));
  });

  test('a hosted game is announced on the network', () async {
    final lan = createLan();
    final found = Completer<FoundGame>();
    final listening = lan.discover().listen((g) {
      if (g.skin == 'phantom' && !found.isCompleted) found.complete(g);
    }, onError: (Object e) {
      if (!found.isCompleted) found.completeError(e);
    });
    addTearDown(listening.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final host = await lan.host('phantom');
    addTearDown(host.close);
    final game = await found.future.timeout(const Duration(seconds: 5));
    expect(game.port, host.port);
  });

  test('two whole games find each other on the network and race', () async {
    final host = await initializeGame(() => GoingUpGame(state: GameState(seed: 1)));
    final guest = await initializeGame(() => GoingUpGame(state: GameState(seed: 2)));
    addTearDown(() {
      host.onRemove();
      guest.onRemove();
    });
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        for (final g in [host, guest]) {
          if (g.state.mode == GameMode.playing) g.state.grace = 1;
          g.update(1 / 60);
        }
        await Future<void>.delayed(const Duration(milliseconds: 4)); // real sockets need real time
      }
    }

    void press(GoingUpGame game, Rect rect) => game.press(Vector2(rect.center.dx, rect.center.dy), touch: true);
    VersusButton button(GoingUpGame game, bool Function(VersusButton b) test) =>
        game.versusScreen.buttons.firstWhere(test);

    press(host, host.versusButton);
    press(host, button(host, (b) => b.label == 'HOST A GAME').rect);
    press(guest, guest.versusButton);
    press(guest, button(guest, (b) => b.label == 'JOIN A GAME').rect);
    for (var i = 0; i < 300 && !guest.versusScreen.buttons.any((b) => b.game != null); i++) {
      await frames(1);
    }
    press(guest, button(guest, (b) => b.game != null).rect);
    for (var i = 0; i < 300 && host.match?.friendHere != true; i++) {
      await frames(1);
    }
    expect(host.versusScreen.page, VersusPage.lobby);
    press(host, button(host, (b) => b.label == 'START').rect);
    for (var i = 0; i < 400 && guest.state.mode != GameMode.playing; i++) {
      await frames(1);
    }
    expect((host.state.mode, guest.state.mode), (GameMode.playing, GameMode.playing));
    await frames(60);
    expect(guest.match!.ghostVisible, isTrue);
    guest.state.mode = GameMode.dead; // the guest crashes
    for (var i = 0; i < 300 && (host.match?.result == null || guest.match?.result == null); i++) {
      await frames(1);
    }
    expect(host.match!.result, MatchResult.won);
    expect(guest.match!.result, MatchResult.lost);
    host.leaveMatch();
    for (var i = 0; i < 100 && guest.match?.friendLeft != true; i++) {
      await frames(1);
    }
    expect(guest.match!.friendLeft, isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
