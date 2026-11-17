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

/// Round badge with an icon: a shield.
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
  final fill = Paint()..color = Palette.text;
  switch (p) {
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

/// A lightning bolt [size] tall: the turbo's mark.
void drawBolt(Canvas canvas, Offset c, double size, Color color) {
  final k = size / 28;
  canvas.drawPath(
      Path()
        ..moveTo(c.dx + 4 * k, c.dy - 14 * k)
        ..lineTo(c.dx - 8 * k, c.dy + 2 * k)
        ..lineTo(c.dx - 1 * k, c.dy + 2 * k)
        ..lineTo(c.dx - 4 * k, c.dy + 14 * k)
        ..lineTo(c.dx + 8 * k, c.dy - 2 * k)
        ..lineTo(c.dx + 1 * k, c.dy - 2 * k)
        ..close(),
      Paint()..color = color);
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

/// 0 at or below [from], 1 at or above [to], easing smoothly in between: how far an effect
/// has faded in as the run's mood (or depth) moves from one to the other.
double ramp(double x, double from, double to) {
  final t = ((x - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Steady pseudo-random number in [0, 1) for a point.
double hash2(double x, double y) {
  final v = math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

/// Smooth value noise in [0, 1): neighbouring points get similar values.
double noise2(double x, double y) {
  final xi = x.floorToDouble(), yi = y.floorToDouble(), xf = x - xi, yf = y - yi;
  final u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  final a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

/// [noise2] with finer detail layered on: ragged, natural-looking edges for ink and fire.
double fbm2(double x, double y) => noise2(x, y) * 0.55 + noise2(x * 2.1, y * 2.1) * 0.3 + noise2(x * 4.3, y * 4.3) * 0.15;

/// A closed blob around [centre] about [radius] across, its edge made ragged by noise that
/// shifts with [time]; [rough] sets how ragged.
Path noisyBlob(Offset centre, double radius, double time, {double rough = 0.32, double seed = 5, double squash = 1}) {
  final path = Path();
  const points = 96;
  for (var i = 0; i <= points; i++) {
    final a = i / points * 2 * math.pi;
    final r = radius * (1 + rough * (fbm2(math.cos(a) * 1.6 + seed, math.sin(a) * 1.6 + time * 0.7) - 0.5));
    final p = centre + Offset(math.cos(a) * r, math.sin(a) * r * squash);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Blinks on for most of each 1.1 s cycle.
bool blinkOn(double time) => time % 1.1 < 0.75;

/// [rect] with all four edges torn ragged (steady for a given [seed]).
Path tornRect(Rect rect, int seed, {double tooth = 10, double depth = 7}) {
  final p = Path()..moveTo(rect.left, rect.top + hash01(seed) * depth);
  var i = 0;
  for (var x = rect.left; x < rect.right; x += tooth) {
    p.lineTo(math.min(x + tooth, rect.right), rect.top + hash01(seed * 31 + ++i) * depth);
  }
  for (var y = rect.top; y < rect.bottom; y += tooth) {
    p.lineTo(rect.right - hash01(seed * 37 + ++i) * depth, math.min(y + tooth, rect.bottom));
  }
  for (var x = rect.right; x > rect.left; x -= tooth) {
    p.lineTo(math.max(x - tooth, rect.left), rect.bottom - hash01(seed * 41 + ++i) * depth);
  }
  for (var y = rect.bottom; y > rect.top; y -= tooth) {
    p.lineTo(rect.left + hash01(seed * 43 + ++i) * depth, math.max(y - tooth, rect.top));
  }
  return p..close();
}

/// A torn strip of parchment filling [rect], with ragged top and bottom edges (steady for a
/// given [seed]) and a few ink blots. [alpha] fades the whole strip.
void drawPaper(Canvas canvas, Rect rect, int seed, {double alpha = 1}) {
  const tooth = 7.0;
  final path = Path()..moveTo(rect.left, rect.top + 3);
  for (var x = rect.left, i = 0; x < rect.right; x += tooth, i++) {
    path.lineTo(math.min(x + tooth, rect.right), rect.top + hash01(seed + i) * 6);
  }
  path.lineTo(rect.right - 2, rect.bottom - 4);
  for (var x = rect.right, i = 0; x > rect.left; x -= tooth, i++) {
    path.lineTo(math.max(x - tooth, rect.left), rect.bottom - hash01(seed + 50 + i) * 6);
  }
  path.close();
  canvas.drawPath(path.shift(const Offset(3, 4)), Paint()..color = Palette.shade.withValues(alpha: 0.35 * alpha));
  canvas.drawPath(path, Paint()..color = Palette.parchment.withValues(alpha: 0.94 * alpha));
  canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.parchmentShade.withValues(alpha: alpha));
  // ink blots near the corners
  final ink = Paint()..color = Palette.ink.withValues(alpha: 0.55 * alpha);
  for (var i = 0; i < 3; i++) {
    final x = rect.left + 10 + hash01(seed + 90 + i) * (rect.width - 20);
    final y = i.isEven ? rect.top + 9 : rect.bottom - 9;
    final r = 1.5 + hash01(seed + 95 + i) * 2.5;
    canvas.drawCircle(Offset(x, y), r, ink);
    canvas.drawCircle(Offset(x + r * 1.6, y + r * 0.6), r * 0.45, ink);
  }
}

/// A memory fragment: a torn shard of the burrow wall with one of Mama's rainbows painted on
/// it, glowing teal and turning slowly. [t] drives the glow and the turn.
void drawFragment(Canvas canvas, Offset c, double t, double r) {
  final pulse = 0.5 + 0.5 * math.sin(t * 3);
  for (final (k, a) in const [(2.4, 0.06), (1.8, 0.09), (1.3, 0.12)]) {
    canvas.drawCircle(c, r * k, Paint()..color = Palette.glimmer.withValues(alpha: a * (0.6 + 0.4 * pulse)));
  }
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(math.sin(t * 0.9) * 0.35);
  final shard = Path()
    ..moveTo(-r * 0.9, -r * 0.6)
    ..lineTo(-r * 0.2, -r * 1.0)
    ..lineTo(r * 0.35, -r * 0.7)
    ..lineTo(r * 0.95, -r * 0.85)
    ..lineTo(r * 0.8, r * 0.3)
    ..lineTo(r * 0.3, r * 0.95)
    ..lineTo(-r * 0.4, r * 0.7)
    ..lineTo(-r * 1.0, r * 0.85)
    ..close();
  canvas.drawPath(shard, Paint()..color = Palette.parchment);
  canvas.save();
  canvas.clipPath(shard);
  final band = r * 0.16;
  for (var k = 0; k < 6; k++) {
    canvas.drawArc(
        Rect.fromCircle(center: Offset(0, r * 0.75), radius: r * 1.05 - k * band),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band + 0.4
          ..color = Palette.rainbow[k].withValues(alpha: 0.85));
  }
  canvas.restore();
  canvas.drawPath(
      shard,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.glimmer.withValues(alpha: 0.7 + 0.3 * pulse));
  canvas.restore();
  // a twinkle orbiting the shard
  final a = t * 2.2;
  final p = c + Offset(math.cos(a) * r * 1.6, math.sin(a) * r * 1.2);
  canvas.drawCircle(p, 1.6, Paint()..color = Palette.moon.withValues(alpha: 0.9));
}

/// A realm's own memory waiting in the tunnel: a small old photograph (two figures under a
/// rainbow, washed to sepia) in a white frame, swaying and glowing warm. [r] is half its width.
void drawPhoto(Canvas canvas, Offset c, double t, double r) {
  final pulse = 0.5 + 0.5 * math.sin(t * 3);
  for (final (k, a) in const [(2.3, 0.06), (1.7, 0.09), (1.25, 0.12)]) {
    canvas.drawCircle(c, r * k, Paint()..color = Palette.sunsetAmber.withValues(alpha: a * (0.6 + 0.4 * pulse)));
  }
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(math.sin(t * 0.9) * 0.22);
  final frame = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.3);
  canvas.drawRect(frame.shift(const Offset(1.5, 2)), Paint()..color = Palette.shade.withValues(alpha: 0.35));
  canvas.drawRect(frame, Paint()..color = Palette.parchment);
  final picture = Rect.fromLTRB(frame.left + r * 0.18, frame.top + r * 0.18, frame.right - r * 0.18, frame.bottom - r * 0.6);
  canvas.drawRect(picture, Paint()..color = Palette.parchmentShade);
  canvas.save();
  canvas.clipRect(picture);
  final band = picture.width * 0.07;
  for (var k = 0; k < 6; k++) {
    canvas.drawArc(
        Rect.fromCircle(center: Offset(0, picture.bottom), radius: picture.width * 0.62 - k * band),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band + 0.4
          ..color = Color.lerp(Palette.rainbow[k], Palette.sepia, 0.55)!);
  }
  // two little bunnies, side by side
  final figure = Paint()..color = Palette.sepia;
  for (final dx in [-picture.width * 0.18, picture.width * 0.16]) {
    final base = Offset(dx, picture.bottom);
    canvas.drawOval(Rect.fromCenter(center: base + Offset(0, -r * 0.28), width: r * 0.42, height: r * 0.5), figure);
    canvas.drawRect(Rect.fromLTWH(base.dx - r * 0.14, base.dy - r * 0.78, r * 0.09, r * 0.32), figure);
    canvas.drawRect(Rect.fromLTWH(base.dx + r * 0.05, base.dy - r * 0.78, r * 0.09, r * 0.32), figure);
  }
  canvas.restore();
  canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Palette.sunsetAmber.withValues(alpha: 0.6 + 0.4 * pulse));
  canvas.restore();
}
