import 'dart:async';
import 'dart:math' as math;

import '../game_state.dart';
import 'lan.dart';

enum MatchPhase {
  /// Connected, waiting for both players to be ready.
  lobby,

  /// 3, 2, 1...
  countdown,

  /// Both flying the same tunnel.
  racing,

  /// Someone crashed: the result is showing, and a rematch can be asked for.
  over,

  /// The match is gone: the friend left before a race finished, or this player left.
  closed,
}

enum MatchResult { won, lost, draw }

/// A two-player race over a [LanLink]. Both players fly the same tunnel (the host picks its
/// seed) and can't touch each other: each sees the other as a see-through ghost. The first to
/// crash loses, and the one still flying wins.
///
/// Messages, one JSON object each, with its type in `t`:
/// * `hello`: what this player is wearing (`skin`, `trail`);
/// * `ready`: ready for the next race; the host starts it once both are, with
/// * `start`: the tunnel's `seed`, then both count down and fly;
/// * `s`: about 20 times a second while flying, where the bunny is (`x`, `wy`), its `m`eters
///   and whether it has a shield (`sh`);
/// * `died`: this player crashed, `at` seconds into the race;
/// * `ended`: this player was still flying when the other's crash arrived, `at` seconds in;
/// * `bye`: leaving.
///
/// Nothing here touches the network itself or runs on a timer: [update] is called every frame
/// after the game's own update, so it can be tested with a pair of links in memory.
class VersusMatch {
  VersusMatch(this.link, this.state, {required this.hosting, math.Random? random})
      : _random = random ?? math.Random() {
    _subscription = link.messages.listen(_inbox.add, onError: (Object _) => _linkLost = true, onDone: () => _linkLost = true);
    _send({'t': 'hello', 'v': Lan.protocol, 'skin': state.skinId, 'trail': state.trailStyleId});
    if (!hosting) setReady(); // the guest is ready on arrival; the host says when to start
  }

  final LanLink link;
  final GameState state;
  final bool hosting;
  final math.Random _random;
  late final StreamSubscription<Map<String, Object?>> _subscription;
  final List<Map<String, Object?>> _inbox = [];
  bool _linkLost = false;

  MatchPhase phase = MatchPhase.lobby;

  /// What the friend is wearing, once they've said hello.
  String? friendSkin, friendTrail;
  bool get friendHere => friendSkin != null;

  /// Whether each player is ready for the next race.
  bool ready = false, friendReady = false;

  static const double countdownSeconds = 3;
  double countdown = 0;
  int seed = 0;

  /// Seconds since the race started.
  double clock = 0;
  double? _myEnd, _friendEnd; // race time when each run ended

  /// The friend's meters, as last heard.
  int friendMeters = 0;

  /// How the last race went, and the score so far.
  MatchResult? result;
  int wins = 0, losses = 0;

  /// The friend left, or the connection dropped. No more races.
  bool friendLeft = false;

  /// The friend's ghost: where it is (shown a moment behind, smoothly), whether it has a
  /// shield, and the world points its trail has passed through.
  bool ghostVisible = false, ghostShield = false;
  double ghostX = GameState.width / 2, ghostWy = 0;
  final List<(double, double, int)> ghostTrail = []; // (x, wy, id)
  int _ghostId = 0;
  final List<(double, double, double)> _samples = []; // (time heard, x, wy)
  double _now = 0, _sendTimer = 0;
  static const double _sendEvery = 1 / 20, _ghostDelay = 0.12;
  static const int _maxGhostTrail = 600;

  /// Ready for the next race (the host's START, or either player's REMATCH).
  void setReady() {
    if (ready || phase == MatchPhase.closed || friendLeft) return;
    ready = true;
    _send({'t': 'ready'});
  }

  /// Leaves the match: the friend hears goodbye.
  void leave() {
    if (phase == MatchPhase.closed && _linkLost) return;
    _send({'t': 'bye'});
    phase = MatchPhase.closed;
    _linkLost = true;
    _subscription.cancel();
    link.close();
  }

  void update(double dt) {
    if (phase == MatchPhase.closed) return;
    _now += dt;
    if (phase == MatchPhase.racing) {
      clock += dt;
      // a crash of our own goes first, so a crash arriving in the same frame is compared fairly
      if (_myEnd == null && state.mode == GameMode.dead && !state.endedByMatch) {
        _myEnd = clock;
        _send({'t': 'died', 'at': clock, 'm': state.meters});
        _settle();
      }
    }
    while (_inbox.isNotEmpty && phase != MatchPhase.closed) {
      _handle(_inbox.removeAt(0));
    }
    if (_linkLost) _lost();

    switch (phase) {
      case MatchPhase.lobby || MatchPhase.over:
        if (hosting && ready && friendReady && friendHere && !friendLeft) {
          seed = _random.nextInt(1 << 30);
          _send({'t': 'start', 'seed': seed});
          _beginCountdown();
        }
      case MatchPhase.countdown:
        countdown -= dt;
        if (countdown <= 0) {
          phase = MatchPhase.racing;
          clock = 0;
          state.startVersusRun(seed);
        }
      case MatchPhase.racing:
        _sendTimer -= dt;
        if (_sendTimer <= 0 && state.mode == GameMode.playing) {
          _sendTimer = _sendEvery;
          _send({
            't': 's',
            'x': _round(state.bunnyX),
            'wy': _round(state.worldY(state.bunnyY)),
            'm': state.meters,
            'sh': state.shield,
          });
        }
      case MatchPhase.closed:
        break;
    }
    _updateGhost();
  }

  void _handle(Map<String, Object?> m) {
    switch (m['t']) {
      case 'hello':
        friendSkin = _string(m['skin']) ?? Shop.defaultSkin.id;
        friendTrail = _string(m['trail']) ?? Shop.defaultTrail.id;
      case 'ready':
        friendReady = true;
      case 'start' when !hosting && (phase == MatchPhase.lobby || phase == MatchPhase.over):
        seed = _int(m['seed']);
        _beginCountdown();
      case 's' when phase == MatchPhase.racing && _friendEnd == null:
        _samples.add((_now, _double(m['x']), _double(m['wy'])));
        if (_samples.length > 30) _samples.removeAt(0);
        friendMeters = _int(m['m']);
        ghostShield = m['sh'] == true;
      case 'died' when phase == MatchPhase.racing:
        _friendEnd = _double(m['at']);
        friendMeters = _int(m['m']);
        if (_myEnd == null) {
          // still flying when the friend crashed: a win, and this run ends here
          _myEnd = clock;
          state.endRunForMatch();
          _send({'t': 'ended', 'at': clock, 'm': state.meters});
          _finish(MatchResult.won);
        } else {
          _settle(); // both crashed before hearing of the other's crash
        }
      case 'ended' when phase == MatchPhase.racing && _myEnd != null:
        _friendEnd = _double(m['at']);
        friendMeters = _int(m['m']);
        _finish(MatchResult.lost);
      case 'bye':
        _linkLost = true;
    }
  }

  /// Both runs have ended: whoever crashed later wins, and a dead heat is a draw.
  void _settle() {
    final mine = _myEnd, theirs = _friendEnd;
    if (mine == null || theirs == null || phase != MatchPhase.racing) return;
    _finish((mine - theirs).abs() < 0.1
        ? MatchResult.draw
        : mine > theirs
            ? MatchResult.won
            : MatchResult.lost);
  }

  void _finish(MatchResult result) {
    this.result = result;
    phase = MatchPhase.over;
    if (result == MatchResult.won) wins++;
    if (result == MatchResult.lost) losses++;
  }

  /// The friend is gone. Mid-race, whoever is still flying wins.
  void _lost() {
    if (friendLeft) return;
    friendLeft = true;
    _subscription.cancel();
    link.close();
    switch (phase) {
      case MatchPhase.racing:
        final flying = _myEnd == null;
        if (flying) state.endRunForMatch();
        _finish(flying ? MatchResult.won : MatchResult.lost);
      case MatchPhase.over:
        break;
      case MatchPhase.lobby || MatchPhase.countdown || MatchPhase.closed:
        phase = MatchPhase.closed;
    }
  }

  void _beginCountdown() {
    phase = MatchPhase.countdown;
    countdown = countdownSeconds;
    ready = friendReady = false;
    result = null;
    _myEnd = _friendEnd = null;
    friendMeters = 0;
    _samples.clear();
    ghostTrail.clear();
    state.toTitle(versus: true);
  }

  /// The ghost is shown [_ghostDelay] behind what was last heard, moving smoothly between the
  /// positions heard (and on along its last heading for a moment if the next one is late).
  void _updateGhost() {
    ghostVisible = phase == MatchPhase.racing && _friendEnd == null && _samples.isNotEmpty;
    if (!ghostVisible) return;
    final t = _now - _ghostDelay;
    var (_, x, wy) = _samples.first;
    if (t >= _samples.last.$1) {
      final (t1, x1, wy1) = _samples.last;
      (x, wy) = (x1, wy1);
      if (_samples.length > 1) {
        final (t0, x0, wy0) = _samples[_samples.length - 2];
        final ahead = math.min(t - t1, 0.2);
        if (t1 > t0) {
          x += (x1 - x0) / (t1 - t0) * ahead;
          wy += (wy1 - wy0) / (t1 - t0) * ahead;
        }
      }
    } else {
      for (var i = _samples.length - 1; i > 0; i--) {
        final (t0, x0, wy0) = _samples[i - 1];
        final (t1, x1, wy1) = _samples[i];
        if (t >= t0) {
          final f = t1 > t0 ? (t - t0) / (t1 - t0) : 1.0;
          (x, wy) = (x0 + (x1 - x0) * f, wy0 + (wy1 - wy0) * f);
          break;
        }
      }
    }
    ghostX = x.clamp(0.0, GameState.width);
    ghostWy = wy;

    final tailX = ghostX, tailWy = ghostWy - GameState.trailTailOffset;
    final last = ghostTrail.isEmpty ? null : ghostTrail.last;
    if (last == null || (last.$1 - tailX).abs() + (last.$2 - tailWy).abs() >= 3) {
      ghostTrail.add((tailX, tailWy, _ghostId++));
    }
    final bottom = state.distance - 40;
    var drop = 0;
    while (drop + 2 < ghostTrail.length && ghostTrail[drop].$2 < bottom && ghostTrail[drop + 1].$2 < bottom) {
      drop++;
    }
    drop = math.max(drop, ghostTrail.length - _maxGhostTrail);
    if (drop > 0) ghostTrail.removeRange(0, drop);
  }

  void _send(Map<String, Object?> message) {
    if (!_linkLost) link.send(message);
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
  static String? _string(Object? v) => v is String ? v : null;
  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static double _double(Object? v) => v is num ? v.toDouble() : 0;
}
