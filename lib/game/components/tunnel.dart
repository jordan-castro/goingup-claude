import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// The tunnel walls, drawn in world coordinates (x, -worldY) as anti-aliased curves through
/// the wall samples, so their edges are smooth.
class Tunnel extends Component with HasGameReference<GoingUpGame> {
  Tunnel() : super(priority: 1);

  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _rimGlow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 9
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Wall colour at world height [wy]: a soft pastel drifting through the rainbow, sinking into
  /// dark violet and indigo as the run's [mood] deepens.
  static Color wallColor(double wy, double mood) {
    final day = HSLColor.fromAHSL(1, (wy * 0.1) % 360, 0.45, 0.68).toColor();
    if (mood <= 0) return day;
    final night = HSLColor.fromAHSL(1, 255 + 25 * math.sin(wy * 0.0015), 0.42, 0.2).toColor();
    return Color.lerp(day, night, mood)!;
  }

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final walls = state.walls;
    if (walls.length < 2) return;
    final left = [for (final s in walls) Offset(s.left, -s.wy)];
    final right = [for (final s in walls) Offset(s.right, -s.wy)];

    final leftFill = Path()
      ..moveTo(-30, left.first.dy)
      ..lineTo(left.first.dx, left.first.dy);
    appendSmoothCurve(leftFill, left);
    leftFill
      ..lineTo(-30, left.last.dy)
      ..close();
    final rightFill = Path()
      ..moveTo(GameState.width + 30, right.first.dy)
      ..lineTo(right.first.dx, right.first.dy);
    appendSmoothCurve(rightFill, right);
    rightFill
      ..lineTo(GameState.width + 30, right.last.dy)
      ..close();

    final mood = game.mood;
    final top = state.distance + state.height;
    final colors = <Color>[], stops = <double>[];
    for (var k = 0; k <= 8; k++) {
      colors.add(wallColor(top - state.height * k / 8, mood));
      stops.add(k / 8);
    }
    final fill = Paint()..shader = ui.Gradient.linear(Offset(0, -top), Offset(0, -state.distance), colors, stops);
    canvas.drawPath(leftFill, fill);
    canvas.drawPath(rightFill, fill);

    canvas.save();
    canvas.clipPath(Path()
      ..addPath(leftFill, Offset.zero)
      ..addPath(rightFill, Offset.zero));
    // sprinkles by day, fading into teal glimmers by night
    final sprinkleAlpha = (1 - mood * 1.4).clamp(0.0, 1.0);
    final glimmerAlpha = (mood * 1.2 - 0.1).clamp(0.0, 1.0);
    final paint = Paint();
    for (final s in walls) {
      if (s.id % 3 != 0) continue;
      if (s.wy < state.distance - 10 || s.wy > top + 10) continue;
      final roomRight = GameState.width - s.right;
      final spots = [
        if (s.left > 26) (5 + hash01(s.id) * (s.left - 24), -s.wy, s.id),
        if (roomRight > 26) (s.right + 19 + hash01(s.id + 5) * (roomRight - 24), -s.wy + 9, s.id + 11),
      ];
      for (final (x, y, id) in spots) {
        if (sprinkleAlpha > 0) _sprinkle(canvas, paint, x, y, id, sprinkleAlpha);
        if (glimmerAlpha > 0) _glimmer(canvas, paint, x, y, id, glimmerAlpha * (0.4 + 0.6 * (0.5 + 0.5 * math.sin(state.time * 2 + id))));
      }
    }
    canvas.restore();

    final leftEdge = Path()..moveTo(left.first.dx, left.first.dy);
    appendSmoothCurve(leftEdge, left);
    final rightEdge = Path()..moveTo(right.first.dx, right.first.dy);
    appendSmoothCurve(rightEdge, right);
    if (mood > 0.3) {
      _rimGlow.color = Palette.rim.withValues(alpha: 0.22 * (mood - 0.3) / 0.7);
      canvas.drawPath(leftEdge, _rimGlow);
      canvas.drawPath(rightEdge, _rimGlow);
    }
    _edgePaint.color = Color.lerp(Palette.ink, Palette.rim, mood)!;
    canvas.drawPath(leftEdge, _edgePaint);
    canvas.drawPath(rightEdge, _edgePaint);
  }

  void _sprinkle(Canvas canvas, Paint paint, double x, double y, int id, double alpha) {
    final color = Palette.sprinkles[(hash01(id + 7) * Palette.sprinkles.length).floor() % Palette.sprinkles.length];
    paint.color = color.withValues(alpha: alpha);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(hash01(id + 3) * math.pi);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -1.5, 9, 3), const Radius.circular(1.5)), paint);
    canvas.restore();
  }

  /// A small four-pointed twinkle.
  void _glimmer(Canvas canvas, Paint paint, double x, double y, int id, double alpha) {
    paint.color = Palette.glimmer.withValues(alpha: alpha);
    final s = 2.5 + hash01(id + 13) * 2;
    canvas.drawPath(
        Path()
          ..moveTo(x, y - s * 1.6)
          ..quadraticBezierTo(x, y, x + s * 1.6, y)
          ..quadraticBezierTo(x, y, x, y + s * 1.6)
          ..quadraticBezierTo(x, y, x - s * 1.6, y)
          ..quadraticBezierTo(x, y, x, y - s * 1.6)
          ..close(),
        paint);
  }
}
