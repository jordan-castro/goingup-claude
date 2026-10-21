import 'package:flame_audio/flame_audio.dart';

import 'game_state.dart';

/// The game's sound effects: one-shot sounds for [SoundCue]s from the rules, and the shop's
/// buttons.
abstract class GameSfx {
  bool get muted;
  set muted(bool value);

  /// Loads the sounds. Safe to call more than once.
  Future<void> load();

  void play(SoundCue cue);
  void dispose();
}

/// No sound at all: for tests, and wherever audio can't play.
class SilentSfx implements GameSfx {
  @override
  bool muted = false;

  /// Everything asked to play, for tests.
  final List<SoundCue> played = [];

  @override
  Future<void> load() async {}

  @override
  void play(SoundCue cue) => played.add(cue);

  @override
  void dispose() {}
}

/// Plays the clips in `assets/audio/sfx/` (made by `tool/make_sfx.py`) from small pools, so
/// a quick run of coins can overlap without starting a new player each time.
class PooledSfx implements GameSfx {
  static const _master = 0.7;

  /// File (without `.wav`), volume and how many may overlap.
  static const Map<Sfx, (String, double, int)> _clips = {
    Sfx.shield: ('shield', 0.35, 1), // quiet, so it doesn't break the mood
    Sfx.bump: ('bump', 0.9, 1),
    Sfx.crash: ('crash', 1.0, 1),
    Sfx.takeoff: ('takeoff', 0.6, 1),
    Sfx.ghost: ('ghost', 0.6, 1),
    Sfx.milestone: ('milestone', 0.7, 1),
    Sfx.newBest: ('new_best', 0.8, 1),
    Sfx.hollowPop: ('hollow_pop', 0.8, 2),
    Sfx.realm: ('realm', 0.75, 1),
    Sfx.memory: ('memory', 0.8, 1),
    Sfx.glitch: ('glitch', 0.5, 1),
    Sfx.click: ('click', 0.6, 2),
    Sfx.buy: ('buy', 0.8, 1),
    Sfx.nope: ('nope', 0.7, 1),
  };
  static const _coinVolume = 0.2; // soft, there are a lot of them
  static const _coinSteps = 5;

  final Map<Sfx, AudioPool> _pools = {};
  final List<AudioPool> _coins = [];
  bool _loading = false;

  @override
  bool muted = false;

  @override
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      for (var i = 1; i <= _coinSteps; i++) {
        _coins.add(await FlameAudio.createPool('sfx/coin_$i.wav', maxPlayers: 3));
      }
      for (final MapEntry(key: sfx, value: (file, _, overlap)) in _clips.entries) {
        _pools[sfx] = await FlameAudio.createPool('sfx/$file.wav', maxPlayers: overlap + 1);
      }
    } catch (_) {
      // No audio output here (or the browser refused): the game simply plays silently.
    }
  }

  @override
  void play(SoundCue cue) {
    if (muted) return;
    final AudioPool? pool;
    final double volume;
    if (cue.sfx == Sfx.coin) {
      pool = cue.step < _coins.length ? _coins[cue.step] : null;
      volume = _coinVolume;
    } else {
      pool = _pools[cue.sfx];
      volume = _clips[cue.sfx]!.$2;
    }
    pool?.start(volume: volume * _master).catchError((Object _) => () async {});
  }

  @override
  void dispose() {
    for (final pool in [..._coins, ..._pools.values]) {
      pool.dispose().catchError((Object _) {});
    }
    _coins.clear();
    _pools.clear();
  }
}
