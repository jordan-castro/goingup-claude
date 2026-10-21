import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// The space behind the tunnel, in the camera's backdrop (field coordinates): a field colour,
/// stars drifting past at different depths and, as the run darkens, violet and teal mist and
/// slow motes rising against the climb.
class Starfield extends Component with HasGameReference<GoingUpGame> {
  /// [random] places the stars and motes (tests pass a seeded one).
  Starfield({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;
  final List<_Star> _stars = [];
  final List<_Mote> _motes = [];
  final _paint = Paint();

  static const _maxMotes = 26;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 70; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble() * GameState.width,
        y: _rng.nextDouble() * GameState.maxHeight,
        depth: 0.05 + _rng.nextDouble() * 0.33,
        phase: _rng.nextDouble() * 8,
        big: _rng.nextDouble() < 0.12,
      ));
    }
    for (var i = 0; i < _maxMotes; i++) {
      _motes.add(_Mote(
        x: _rng.nextDouble() * GameState.width,
        y: _rng.nextDouble() * GameState.maxHeight,
        rise: 8 + _rng.nextDouble() * 22,
        phase: _rng.nextDouble() * 6.3,
      ));
    }
  }

  @override
  void update(double dt) {
    final state = game.state;
    final step = math.min(dt, 0.05);
    final dy = state.speed * step;
    for (final s in _stars) {
      s.y += dy * s.depth;
      if (s.y > state.height + 6) {
        s.y -= state.height + 12;
        s.x = _rng.nextDouble() * GameState.width;
      }
    }
    for (final m in _motes) {
      m.y -= m.rise * step;
      if (m.y < -10) {
        m.y += state.height + 20;
        m.x = _rng.nextDouble() * GameState.width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final mood = game.mood;
    final h = state.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, GameState.width, h), _paint..color = Color.lerp(Palette.space, Palette.spaceNight, mood)!);

    if (mood > 0.02) _mist(canvas, mood, state.time, h);

    final starColor = Color.lerp(Palette.star, Palette.starNight, mood)!;
    for (final s in _stars) {
      if (s.y > h + 4) continue;
      final twinkle = 0.5 + 0.5 * math.sin(state.time * (1.3 + mood) + s.phase);
      if (s.big) {
        _paint.color = starColor.withValues(alpha: 0.45 + 0.4 * twinkle);
        canvas.drawCircle(Offset(s.x, s.y), 1.7, _paint);
      } else {
        final base = 0.15 + s.depth * 1.2;
        _paint.color = starColor.withValues(alpha: (base * (1 - 0.6 * mood * (1 - twinkle))).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(s.x, s.y), 1.1, _paint);
      }
    }

    final shown = (_maxMotes * mood).round();
    for (var i = 0; i < shown; i++) {
      final m = _motes[i];
      final x = m.x + math.sin(state.time * 0.7 + m.phase) * 6;
      final glow = 0.5 + 0.5 * math.sin(state.time * 1.6 + m.phase * 2);
      _paint.color = Palette.glimmer.withValues(alpha: 0.08 * mood * (0.5 + glow));
      canvas.drawCircle(Offset(x, m.y), 4.5, _paint);
      _paint.color = Palette.glimmer.withValues(alpha: 0.55 * mood * (0.4 + 0.6 * glow));
      canvas.drawCircle(Offset(x, m.y), 1.3, _paint);
    }
  }

  /// Big soft patches of violet and teal that drift slowly.
  void _mist(Canvas canvas, double mood, double time, double h) {
    const colors = [Palette.mistViolet, Palette.mistTeal, Palette.mistViolet];
    for (var i = 0; i < colors.length; i++) {
      final cx = GameState.width * (0.2 + 0.3 * i) + math.sin(time * 0.05 + i * 2.1) * 70;
      final cy = h * (0.2 + 0.3 * i) + math.cos(time * 0.04 + i * 1.3) * 90;
      final r = 160.0 + 40 * i;
      final paint = Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
          colors[i].withValues(alpha: 0.18 * mood),
          colors[i].withValues(alpha: 0),
        ]);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }
}

class _Star {
  _Star({required this.x, required this.y, required this.depth, required this.phase, required this.big});

  double x, y;
  final double depth, phase;
  final bool big;
}

class _Mote {
  _Mote({required this.x, required this.y, required this.rise, required this.phase});

  double x, y;
  final double rise, phase;
}
