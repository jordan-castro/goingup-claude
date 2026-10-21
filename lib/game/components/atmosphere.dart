import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// Drawn over the world (under the HUD) as the run darkens: slow bands of fog drifting down
/// and a vignette closing in from the edges, closer and slowly breathing in the Void. Then,
/// realm by realm: ash falling through everything (ashfall), a thick fog hanging over the way
/// ahead (the hollow), and from ashfall on the light failing and flickering now and then.
/// Field coordinates; nothing at all while bright.
class Atmosphere extends Component with HasGameReference<GoingUpGame> {
  Atmosphere({math.Random? random})
      : _rng = random ?? math.Random(),
        super(priority: -1); // under the HUD

  final math.Random _rng;
  final List<_Flake> _ash = [];
  static const _maxAsh = 70;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < _maxAsh; i++) {
      _ash.add(_Flake(
        _rng.nextDouble() * GameState.width,
        _rng.nextDouble() * GameState.maxHeight,
        0.6 + _rng.nextDouble() * 1.8,
        _rng.nextDouble() * 6.3,
      ));
    }
  }

  @override
  void update(double dt) {
    final state = game.state;
    final step = math.min(dt, 0.05);
    for (final f in _ash) {
      // ash drifts down on its own, and streams past faster the faster the bunny climbs
      f.y += (18 + state.speed * 0.25 * f.size / 2.4) * step;
      f.x += math.sin(state.time * 0.8 + f.phase) * 10 * step;
      if (f.y > state.height + 6) {
        f.y = -6;
        f.x = _rng.nextDouble() * GameState.width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final mood = game.mood, deep = game.deep;
    if (mood < 0.02) return;
    final st = game.stages;
    final h = game.state.height, t = game.state.time;
    const w = GameState.width;

    final fogColor = st.mix(Palette.fog, Palette.fog, const Color(0xFF8A7A6A), const Color(0xFFB8BCB4),
        const Color(0xFF5A1018));
    for (var i = 0; i < 3; i++) {
      const band = 200.0;
      final y = (t * (10 + 6 * i) + i * 330) % (h + band * 2) - band;
      final paint = Paint()
        ..shader = ui.Gradient.linear(Offset(0, y), Offset(0, y + band), [
          fogColor.withValues(alpha: 0),
          fogColor.withValues(alpha: 0.07 * mood + 0.03 * deep + 0.1 * st.hollow),
          fogColor.withValues(alpha: 0),
        ], [
          0,
          0.5,
          1
        ]);
      canvas.drawRect(Rect.fromLTWH(0, y, w, band), paint);
    }

    // the hollow: fog hangs thick over the way ahead, thinning toward the bunny
    if (st.hollow > 0.01) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h * 0.5),
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.5), [
              fogColor.withValues(alpha: 0.42 * st.hollow),
              fogColor.withValues(alpha: 0),
            ]));
    }

    // ashfall: flakes of ash falling through everything, thinning in the Void
    final ash = st.dread * (1 - 0.6 * st.abyss);
    if (ash > 0.01) {
      final paint = Paint();
      for (var i = 0; i < (_maxAsh * ash).round(); i++) {
        final f = _ash[i];
        paint.color = const Color(0xFFD8D2C8).withValues(alpha: 0.5 * ash);
        canvas.save();
        canvas.translate(f.x, f.y);
        canvas.rotate(t * 2 + f.phase);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: f.size * 1.6, height: f.size), paint);
        canvas.restore();
      }
    }

    final breath = deep * (0.5 + 0.5 * math.sin(t * 1.1));
    final vignette = Paint()
      ..shader = ui.Gradient.radial(Offset(w / 2, h * 0.55), h * (0.78 - 0.04 * breath), [
        Palette.shade.withValues(alpha: 0),
        Palette.shade.withValues(alpha: 0.72 * mood + 0.2 * deep),
      ], [
        0.4 - 0.1 * deep,
        1
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignette); // past the radius the edge colour holds

    // from ashfall on, the light fails now and then: a dark flicker, a few frames long
    final chunk = (t * 14).floor();
    if (st.dread > 0 && hash01(chunk * 7 + 3) < 0.035 * st.dread) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Palette.shade.withValues(alpha: 0.45 * st.dread));
    }
  }
}

class _Flake {
  _Flake(this.x, this.y, this.size, this.phase);

  double x, y;
  final double size, phase;
}
