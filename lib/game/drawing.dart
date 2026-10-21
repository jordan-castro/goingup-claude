import 'dart:math' as math;
import 'dart:ui';

import 'game_state.dart';
import 'palette.dart';

/// Small canvas helpers shared by the Flame components.

/// A flat gold coin; [spin] squashes it sideways so it looks like it's turning.
void drawCoin(Canvas canvas, Offset c, double r, {double spin = 1}) {
  final halfW = r * math.max(0.25, spin.abs());
  final rect = Rect.fromCenter(center: c, width: halfW * 2, height: r * 2);
  canvas.drawOval(rect, Paint()..color = Palette.coin);
  canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.coinRim);
  if (halfW > r * 0.5) {
    canvas.drawLine(
        c.translate(0, -r * 0.45),
        c.translate(0, r * 0.45),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Palette.coinRim);
  }
}

/// Round badge with an icon: double chevrons up (boost) or down (slow), pause bars (freeze),
/// or a shield.
void drawPowerUp(Canvas canvas, Offset c, PowerUp p, double r) {
  canvas.drawCircle(c, r, Paint()..color = Palette.powerUp(p));
  canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Palette.ink);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(r / 13); // icons are drawn for a radius of 13
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Palette.text;
  final fill = Paint()..color = Palette.text;
  switch (p) {
    case PowerUp.boost:
    case PowerUp.slow:
      final dir = p == PowerUp.boost ? 1.0 : -1.0;
      for (final dy in const [-3.0, 3.5]) {
        canvas.drawPath(
            Path()
              ..moveTo(-5, dy + 2.5 * dir)
              ..lineTo(0, dy - 2.5 * dir)
              ..lineTo(5, dy + 2.5 * dir),
            stroke);
      }
    case PowerUp.freeze:
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -5.5, 3.5, 11), const Radius.circular(1)), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1.5, -5.5, 3.5, 11), const Radius.circular(1)), fill);
    case PowerUp.shield:
      canvas.drawPath(
          Path()
            ..moveTo(0, -7)
            ..lineTo(6, -4.5)
            ..lineTo(6, 0)
            ..quadraticBezierTo(5.5, 5, 0, 7.5)
            ..quadraticBezierTo(-5.5, 5, -6, 0)
            ..lineTo(-6, -4.5)
            ..close(),
          fill);
  }
  canvas.restore();
}

/// Dark rounded panel with a light edge, behind HUD text.
void drawPanel(Canvas canvas, Rect rect, {Color edge = Palette.panelEdge}) {
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
  canvas.drawRRect(rrect, Paint()..color = Palette.panel);
  canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = edge);
}

/// Continues [path] (already at points.first) through [points] with quadratic curves that pass
/// through each segment's midpoint, so the line has no corners.
void appendSmoothCurve(Path path, List<Offset> points) {
  for (var i = 1; i < points.length - 1; i++) {
    final p = points[i], mid = (points[i] + points[i + 1]) / 2;
    path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
}

/// Steady pseudo-random number in [0, 1) for an id, so decorations don't flicker.
double hash01(int n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Blinks on for most of each 1.1 s cycle.
bool blinkOn(double time) => time % 1.1 < 0.75;
