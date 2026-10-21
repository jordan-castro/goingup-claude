import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';

/// Where the last run ended: a dashed line across the tunnel, a "LAST CRASH" label, and a
/// see-through ghost bunny with a halo. World coordinates.
class CrashMarkerView extends Component with HasGameReference<GoingUpGame> {
  CrashMarkerView() : super(priority: 3);

  static const double _bp = GameState.bunnyPixel;
  final _ghostPaint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final m = state.marker;
    if (m == null || state.mode == GameMode.title) return;
    final sy = state.screenY(m.wy);
    if (sy < -80 || sy > state.height + 60) return;
    final y = -m.wy;

    final dash = Paint()
      ..color = Palette.line
      ..strokeWidth = 2;
    for (var x = -((state.time * 40) % 14); x < GameState.width; x += 14) {
      canvas.drawLine(Offset(x, y), Offset(x + 8, y), dash);
    }

    const label = 'LAST CRASH';
    final w = PixelFont.widthOf(label, 2) + 14;
    final lx = m.x > GameState.width / 2 ? 12.0 : GameState.width - 12 - w;
    final ly = y - 34;
    drawPanel(canvas, Rect.fromLTWH(lx, ly, w, 26));
    PixelFont.draw(canvas, label, lx + 7, ly + 6, 2, Palette.text);

    if (m.fade > 0) {
      final gy = y + math.sin(state.time * 3) * 3 - (1 - m.fade) * 34;
      final ghost = game.sprites.ghost;
      _ghostPaint.color = Color.fromRGBO(255, 255, 255, 0.6 * m.fade);
      canvas.drawImageRect(
          ghost,
          Rect.fromLTWH(0, 0, ghost.width.toDouble(), ghost.height.toDouble()),
          Rect.fromLTWH(m.x - 8 * _bp, gy - 14 * _bp, ghost.width * _bp, ghost.height * _bp),
          _ghostPaint);
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Palette.sun.withValues(alpha: 0.95 * m.fade);
      canvas.drawOval(Rect.fromCenter(center: Offset(m.x, gy - 14 * _bp - 6), width: 22, height: 7), halo);
    }
  }
}
