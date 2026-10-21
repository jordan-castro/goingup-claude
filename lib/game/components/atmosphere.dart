import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// Drawn over the world (under the HUD) as the run darkens: slow bands of fog drifting down
/// and a vignette closing in from the edges. Field coordinates; nothing at all while bright.
class Atmosphere extends Component with HasGameReference<GoingUpGame> {
  Atmosphere() : super(priority: -1); // under the HUD

  @override
  void render(Canvas canvas) {
    final mood = game.mood;
    if (mood < 0.02) return;
    final h = game.state.height, t = game.state.time;
    const w = GameState.width;

    for (var i = 0; i < 3; i++) {
      const band = 200.0;
      final y = (t * (10 + 6 * i) + i * 330) % (h + band * 2) - band;
      final paint = Paint()
        ..shader = ui.Gradient.linear(Offset(0, y), Offset(0, y + band), [
          Palette.fog.withValues(alpha: 0),
          Palette.fog.withValues(alpha: 0.07 * mood),
          Palette.fog.withValues(alpha: 0),
        ], [
          0,
          0.5,
          1
        ]);
      canvas.drawRect(Rect.fromLTWH(0, y, w, band), paint);
    }

    final vignette = Paint()
      ..shader = ui.Gradient.radial(Offset(w / 2, h * 0.55), h * 0.78, [
        Palette.shade.withValues(alpha: 0),
        Palette.shade.withValues(alpha: 0.62 * mood),
      ], [
        0.45,
        1
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignette); // past the radius the edge colour holds
  }
}
