import 'package:flame_audio/flame_audio.dart';

/// The game's soundtrack, driven by the run's mood (0 = bright start, 1 = dark and mystic).
abstract class GameMusic {
  bool get muted;
  set muted(bool value);

  /// Starts playback. Safe to call more than once. On the web it must follow a tap or click.
  Future<void> start();

  /// Called every frame. [quiet] turns the music down (on the game-over screen).
  void update(double mood, {required bool quiet});

  void pause();
  void resume();
  void dispose();
}

/// Volume of the day, dusk and night layers for a [mood] from 0 (bright) to 1 (dark).
({double day, double dusk, double night}) musicMix(double mood) {
  double ramp(double from, double to) {
    final t = ((mood - from) / (to - from)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  return (
    day: 1 - ramp(0.2, 0.65),
    dusk: ramp(0.05, 0.4) * (1 - 0.7 * ramp(0.7, 1.0)),
    night: ramp(0.4, 0.9),
  );
}

/// No sound at all: for tests, and wherever audio can't play.
class SilentMusic implements GameMusic {
  @override
  bool muted = false;

  @override
  Future<void> start() async {}

  @override
  void update(double mood, {required bool quiet}) {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void dispose() {}
}

/// Plays the three loops in `assets/audio/` (made by `tool/make_music.py`) together and
/// crossfades them with the mood. They share one tempo and length, so they stay in step.
class LayeredMusic implements GameMusic {
  static const _files = ['day.wav', 'dusk.wav', 'night.wav'];
  static const _volume = 0.55, _quietVolume = 0.25;

  final List<AudioPlayer> _players = [];
  final List<double> _applied = [-1, -1, -1];
  bool _starting = false, _paused = false, _muted = false, _quiet = false;
  double _mood = 0;

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
  void update(double mood, {required bool quiet}) {
    _mood = mood;
    _quiet = quiet;
    _apply();
  }

  void _apply({bool force = false}) {
    if (_players.length != _files.length) return;
    final mix = musicMix(_mood);
    final master = _muted ? 0.0 : (_quiet ? _quietVolume : _volume);
    final levels = [mix.day, mix.dusk, mix.night];
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
