import 'package:flame_audio/flame_audio.dart';

import 'stages.dart';

/// The game's soundtrack, driven by how far the climb has gone: its mood (0 bright, 1 full
/// dark) and how deep into the Void it is (0 to 1).
abstract class GameMusic {
  bool get muted;
  set muted(bool value);

  /// Starts playback. Safe to call more than once. On the web it must follow a tap or click.
  Future<void> start();

  /// Called every frame. [quiet] turns the music down (on the game-over screen and while a
  /// memory is showing).
  void update(double mood, double deep, {required bool quiet});

  void pause();
  void resume();
  void dispose();
}

/// Volume of each layer as the climb goes up: the bright day tune in the rainbow sky, the warm
/// dusk pad at twilight, the broken music box in ashfall and the hollow with the night drone
/// rising under it, and the heartbeat of the void.
({double day, double dusk, double creep, double night, double abyss}) musicMix(double mood, double deep) {
  final st = Stages(mood, deep);
  return (
    day: st.candy,
    dusk: st.wallpaper + 0.3 * st.rust,
    creep: 0.85 * st.rust + st.hollow + 0.35 * st.abyss,
    night: 0.45 * st.rust + 0.7 * st.hollow + 0.5 * st.abyss,
    abyss: st.abyss,
  );
}

/// No sound at all: for tests, and wherever audio can't play.
class SilentMusic implements GameMusic {
  @override
  bool muted = false;

  @override
  Future<void> start() async {}

  @override
  void update(double mood, double deep, {required bool quiet}) {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void dispose() {}
}

/// Plays the five loops in `assets/audio/` (made by `tool/make_music.py`) together and
/// crossfades them as the climb goes up. They share one tempo and length, so they stay in step.
class LayeredMusic implements GameMusic {
  static const _files = ['day.wav', 'dusk.wav', 'creep.wav', 'night.wav', 'void.wav'];
  static const _volume = 0.55, _quietVolume = 0.25;

  final List<AudioPlayer> _players = [];
  final List<double> _applied = [-1, -1, -1, -1, -1];
  bool _starting = false, _paused = false, _muted = false, _quiet = false;
  double _mood = 0, _deep = 0;

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    _muted = value;
    _apply();
  }

  @override
  Future<void> start() async {
    if (_starting) return;
    _starting = true;
    try {
      await FlameAudio.audioCache.loadAll(_files);
      for (final file in _files) {
        _players.add(await FlameAudio.loopLongAudio(file, volume: 0));
      }
      _apply(force: true);
      if (_paused) {
        for (final p in _players) {
          await p.pause();
        }
      }
    } catch (_) {
      // No audio output here (or the browser refused): the game simply plays silently.
    }
  }

  @override
  void update(double mood, double deep, {required bool quiet}) {
    _mood = mood;
    _deep = deep;
    _quiet = quiet;
    _apply();
  }

  void _apply({bool force = false}) {
    if (_players.length != _files.length) return;
    final mix = musicMix(_mood, _deep);
    final master = _muted ? 0.0 : (_quiet ? _quietVolume : _volume);
    final levels = [mix.day, mix.dusk, mix.creep, mix.night, mix.abyss];
    for (var i = 0; i < _players.length; i++) {
      final v = levels[i] * master;
      if (force || (v - _applied[i]).abs() > 0.01) {
        _applied[i] = v;
        _players[i].setVolume(v).catchError((Object _) {});
      }
    }
  }

  @override
  void pause() {
    _paused = true;
    for (final p in _players) {
      p.pause().catchError((Object _) {});
    }
  }

  @override
  void resume() {
    _paused = false;
    for (final p in _players) {
      p.resume().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    for (final p in _players) {
      p.dispose().catchError((Object _) {});
    }
    _players.clear();
  }
}
