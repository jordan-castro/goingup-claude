import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/versus/lan.dart';
import 'package:goingup/game/versus/match.dart';

const _frame = 1 / 60;

/// Two players linked in memory: the host and the guest, each with their own game.
class _Pair {
  _Pair({String hostSkin = 'snowball', String guestSkin = 'snowball'}) {
    final (a, b) = LanLink.pair();
    hostState = _wearing(hostSkin, 1);
    guestState = _wearing(guestSkin, 2);
    host = VersusMatch(a, hostState, hosting: true);
    guest = VersusMatch(b, guestState, hosting: false);
  }

  late final GameState hostState, guestState;
  late final VersusMatch host, guest;

  /// One frame on both games, then lets the messages through.
  Future<void> frame({bool hostSteers = true, bool guestSteers = true}) async {
    for (final (state, match, steers) in [(hostState, host, hostSteers), (guestState, guest, guestSteers)]) {
      if (steers && state.mode == GameMode.playing) {
        state.grace = 1; // the autopilot flies straight through anything
        _autopilot(state);
      }
      state.update(_frame);
      match.update(_frame);
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> frames(int n, {bool hostSteers = true, bool guestSteers = true}) async {
    for (var i = 0; i < n; i++) {
      await frame(hostSteers: hostSteers, guestSteers: guestSteers);
    }
  }

  /// The host presses START and the countdown runs out.
  Future<void> startRace() async {
    await frames(2);
    host.setReady();
    await frames(2);
    expect((host.phase, guest.phase), (MatchPhase.countdown, MatchPhase.countdown));
    await frames((VersusMatch.countdownSeconds / _frame).ceil() + 1);
    expect((host.phase, guest.phase), (MatchPhase.racing, MatchPhase.racing));
  }
}

GameState _wearing(String skin, int seed) {
  final state = GameState(seed: seed);
  if (skin != Shop.defaultSkin.id) state.restore(SavedProgress(owned: [skin], skin: skin));
  return state..pauseForMemories = true;
}

void _autopilot(GameState game) {
  final (l, r) = game.wallAt(game.distance + game.height - (game.bunnyY - 60));
  game.pointerMove((l + r) / 2, game.height * 0.72);
}

/// Steers [state] into the right wall, without grace.
void _crashInto(GameState state) {
  state.grace = 0;
  state.pointerDown(GameState.width / 2, state.height * 0.72);
  state.pointerMove(GameState.width, state.height * 0.72);
}

void main() {
  test('the two say hello, and the host starts the race on the same tunnel for both', () async {
    final p = _Pair(hostSkin: 'mint', guestSkin: 'comet');
    await p.frames(2);
    expect(p.host.friendSkin, 'comet');
    expect(p.guest.friendSkin, 'mint');
    expect(p.host.friendReady, isTrue, reason: 'the guest is ready on arrival');
    expect(p.host.phase, MatchPhase.lobby, reason: 'the host has not pressed START');

    p.host.setReady();
    await p.frames(2);
    expect(p.guest.phase, MatchPhase.countdown);
    expect(p.guest.seed, p.host.seed);
    p.guestState.pointerDown(GameState.width / 2, 400);
    expect(p.guestState.mode, GameMode.title, reason: 'a press during the countdown does not start early');

    await p.frames((VersusMatch.countdownSeconds / _frame).ceil() + 1);
    expect(p.hostState.mode, GameMode.playing);
    expect(p.guestState.mode, GameMode.playing);
    expect(p.guestState.holding, isTrue, reason: 'the hold from the countdown steers straight away');
    await p.frames(240);
    final hostWalls = {for (final s in p.hostState.walls) s.wy: (s.left, s.right)};
    final shared = p.guestState.walls.where((s) => hostWalls.containsKey(s.wy)).toList();
    expect(shared, isNotEmpty);
    for (final s in shared) {
      expect(hostWalls[s.wy], (s.left, s.right));
    }
  });

  test('the friend shows as a ghost close behind where they really are, with a trail', () async {
    final p = _Pair();
    await p.startRace();
    await p.frames(120);
    expect(p.host.ghostVisible, isTrue);
    expect(p.host.ghostX, closeTo(p.guestState.bunnyX, 30));
    final guestWy = p.guestState.worldY(p.guestState.bunnyY);
    expect(p.host.ghostWy, inInclusiveRange(guestWy - 120, guestWy + 5), reason: 'a moment behind, never ahead');
    expect(p.host.ghostTrail.length, greaterThan(20));
    expect(p.host.friendMeters, closeTo(p.guestState.meters, 1));
  });

  test("the first to crash loses, the other's run ends there and wins, and a rematch starts a new tunnel", () async {
    final p = _Pair();
    await p.startRace();
    await p.frames(60);
    _crashInto(p.guestState);
    for (var i = 0; i < 600 && (p.host.result == null || p.guest.result == null); i++) {
      await p.frame(guestSteers: false);
    }
    expect(p.guest.result, MatchResult.lost);
    expect(p.host.result, MatchResult.won);
    expect(p.hostState.mode, GameMode.dead);
    expect(p.hostState.endedByMatch, isTrue, reason: 'the winner did not crash');
    expect(p.hostState.lastMeters, isNotNull);
    expect((p.host.wins, p.host.losses, p.guest.wins, p.guest.losses), (1, 0, 0, 1));
    expect(p.host.friendMeters, p.guestState.meters);
    expect(p.guest.friendMeters, p.hostState.meters);
    expect(p.hostState.canRetry, isFalse, reason: 'a new race needs both players');

    final firstSeed = p.host.seed;
    p.guest.setReady();
    await p.frames(2);
    expect(p.host.friendReady, isTrue);
    expect(p.host.phase, MatchPhase.over, reason: 'the host has not asked for a rematch yet');
    p.host.setReady();
    await p.frames(2);
    expect((p.host.phase, p.guest.phase), (MatchPhase.countdown, MatchPhase.countdown));
    expect(p.guest.seed, p.host.seed);
    expect(p.host.seed, isNot(firstSeed));
    expect(p.hostState.mode, GameMode.title);
  });

  test('crashing at the same moment is a draw', () async {
    final p = _Pair();
    await p.startRace();
    await p.frames(30);
    // both crash in the same frame, before either hears of the other's crash
    for (final state in [p.hostState, p.guestState]) {
      state.mode = GameMode.dead;
    }
    await p.frames(3, hostSteers: false, guestSteers: false);
    expect(p.host.result, MatchResult.draw);
    expect(p.guest.result, MatchResult.draw);
    expect((p.host.wins, p.host.losses), (0, 0));
  });

  test('a friend leaving mid-race leaves the one still flying the winner', () async {
    final p = _Pair();
    await p.startRace();
    await p.frames(30);
    p.guest.leave();
    await p.frames(2);
    expect(p.host.friendLeft, isTrue);
    expect(p.host.result, MatchResult.won);
    expect(p.hostState.mode, GameMode.dead);
    expect(p.guest.phase, MatchPhase.closed);
    p.host.setReady();
    expect(p.host.ready, isFalse, reason: 'no rematch without a friend');
  });

  test('a friend leaving before the race closes the match', () async {
    final p = _Pair();
    await p.frames(2);
    p.host.leave();
    await p.frames(2);
    expect(p.guest.phase, MatchPhase.closed);
    expect(p.guest.friendLeft, isTrue);
  });

  test('in a race memories go straight into the book instead of pausing the run', () async {
    final p = _Pair();
    await p.startRace();
    final state = p.hostState;
    state.pickups.add(Pickup.memory(state.bunnyX, state.worldY(state.bunnyY), Memories.arrivalOf(0), 0));
    await p.frame();
    expect(state.memories, contains('sky-0'));
    expect(state.readingMemory, isFalse);
    expect(state.toast, 'A MEMORY. READ IT IN THE BOOK.');
    expect(state.marker, isNull, reason: 'no last-crash ghost in a race');
  });

  test('games hosted on a network are found and joined', () async {
    final network = MemoryNetwork();
    final hostLan = network.lan(), guestLan = network.lan();
    final host = await hostLan.host('ember');
    final joins = <LanLink>[];
    host.joins.listen(joins.add);
    final found = await guestLan.discover().first;
    expect(found.skin, 'ember');
    final link = await guestLan.join(found.address, port: found.port);
    await Future<void>.delayed(Duration.zero);
    expect(joins, hasLength(1));
    final heard = joins.single.messages.first;
    link.send({'t': 'hello'});
    expect((await heard)['t'], 'hello');
  });
}
