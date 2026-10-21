import 'dart:math' as math;
import 'dart:ui';

import '../drawing.dart';
import '../memories.dart';
import '../palette.dart';

/// The little animated pictures memories come back with: sepia ink on old paper, like a
/// faded photograph that moves. Each is drawn in a 320 x 170 box, scaled to fit [rect]; [t] is
/// seconds since the memory came back, which drives the animation. The picture develops like
/// an old photograph (washed out white at first), the view drifts slowly closer, and dust
/// floats through the light.
void drawMemoryScene(Canvas canvas, Rect rect, MemoryScene scene, double t) {
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / _w, rect.height / _h);
  canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = _paper);
  // a slow drift closer, with a little sway, like a camera that can't keep still
  final zoom = 1 + 0.08 * ramp(t, 0, 9);
  canvas.save();
  canvas.translate(_w / 2 + math.sin(t * 0.35) * 4, _h / 2 + math.cos(t * 0.27) * 2);
  canvas.scale(zoom);
  canvas.translate(-_w / 2, -_h / 2);
  _Scene(canvas, t).draw(scene);
  canvas.restore();
  _dust(canvas, t);
  _filmWear(canvas, t);
  // developing: the image comes up out of a washed-out white
  final develop = 1 - ramp(t, 0.25, 1.7);
  if (develop > 0) canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = _glow.withValues(alpha: develop));
  canvas.restore();
  // a dark wooden frame
  canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF3A2618));
}

const double _w = 320, _h = 170;
const _paper = Color(0xFFE8D8B4);
const _ink = Color(0xFF3B2A1C);
const _wash = Color(0xFFB89A6E); // a lighter ink wash
const _glow = Color(0xFFF7EBC8);

/// Specks of dust drifting through the projector's light, some catching it, some dark.
void _dust(Canvas canvas, double t) {
  final paint = Paint();
  for (var i = 0; i < 16; i++) {
    final x = (hash01(i + 200) * _w + t * (4 + 8 * hash01(i + 220))) % _w;
    final y = (hash01(i + 210) * _h + math.sin(t * 0.7 + i) * 10 - t * 3 * hash01(i + 230)) % _h;
    final light = i.isEven;
    paint.color = (light ? _glow : _ink).withValues(alpha: 0.35 + 0.3 * math.sin(t * 2 + i));
    canvas.drawCircle(Offset(x, y), 0.6 + hash01(i + 240) * 1.1, paint);
  }
}

/// Old-film wear: a vignette, a flickering exposure and the odd scratch.
void _filmWear(Canvas canvas, double t) {
  final flicker = 0.04 + 0.04 * hash01((t * 12).floor());
  canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = _ink.withValues(alpha: flicker));
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = Gradient.radial(const Offset(_w / 2, _h / 2), _w * 0.62, [
          _ink.withValues(alpha: 0),
          _ink.withValues(alpha: 0.55),
        ], [
          0.55,
          1
        ]));
  final frame = (t * 8).floor();
  if (hash01(frame) < 0.5) {
    final x = hash01(frame + 7) * _w;
    canvas.drawLine(Offset(x, 0), Offset(x + 3, _h),
        Paint()
          ..strokeWidth = 0.8
          ..color = _ink.withValues(alpha: 0.35));
  }
}

class _Scene {
  _Scene(this.c, this.t);

  final Canvas c;
  final double t;
  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint ink([double alpha = 1]) => _fill..color = _ink.withValues(alpha: alpha);
  Paint wash([double alpha = 1]) => _fill..color = _wash.withValues(alpha: alpha);
  Paint glow([double alpha = 1]) => _fill..color = _glow.withValues(alpha: alpha);
  Paint stroke(Color color, double width, [double alpha = 1]) => _line
    ..color = color.withValues(alpha: alpha)
    ..strokeWidth = width;

  /// Eases from 0 to 1 between [from] and [to] seconds.
  double at(double from, double to) => ramp(t, from, to);

  void draw(MemoryScene scene) {
    switch (scene) {
      case MemoryScene.wings:
        return _wings();
      case MemoryScene.oak:
        return _oak();
      case MemoryScene.seven:
        return _seven();
      case MemoryScene.rainbows:
        return _rainbows();
      case MemoryScene.sunset:
        return _sunset();
      case MemoryScene.longShadows:
        return _longShadows();
      case MemoryScene.door:
        return _door();
      case MemoryScene.hiding:
        return _hiding();
      case MemoryScene.constellation:
        return _constellation();
      case MemoryScene.sevenShadows:
        return _sevenShadows();
      case MemoryScene.crying:
        return _crying();
      case MemoryScene.moonCalls:
        return _moonCalls();
      case MemoryScene.runes:
        return _runes();
      case MemoryScene.bargain:
        return _bargain();
      case MemoryScene.forgetting:
        return _forgetting();
      case MemoryScene.brothers:
        return _brothers();
      case MemoryScene.eclipse:
        return _eclipse();
      case MemoryScene.feeding:
        return _feeding();
      case MemoryScene.falling:
        return _falling();
      case MemoryScene.name:
        return _name();
    }
  }

  // ---------- shared pieces ----------

  /// A bunny seen from the side-ish front: body, head and two long ears, standing on [feet].
  /// [s] is its height. [ears] tilts the ears (0 upright, positive droops them).
  ///
  /// Every bunny is alive: its eyes (pale on a dark bunny, dark on a pale one) blink now and
  /// then, and its ears give a twitch.
  void bunny(Offset feet, double s, Paint paint, {double ears = 0, bool wings = false, double flap = 0}) {
    final body = Rect.fromCenter(center: feet + Offset(0, -s * 0.28), width: s * 0.55, height: s * 0.56);
    final head = feet + Offset(0, -s * 0.66);
    final seed = (feet.dx * 7 + feet.dy * 3 + s).round();
    final beat = t + hash01(seed) * 5;
    final twitch = (beat * 0.8) % 2.3 < 0.12 ? 0.12 : 0.0;
    if (wings) {
      for (final side in const [-1.0, 1.0]) {
        final root = feet + Offset(side * s * 0.2, -s * 0.42);
        final tip = root + Offset(side * s * 0.55, -s * (0.25 + 0.2 * flap));
        c.drawPath(
            Path()
              ..moveTo(root.dx, root.dy)
              ..quadraticBezierTo(root.dx + side * s * 0.3, root.dy - s * 0.45, tip.dx, tip.dy)
              ..quadraticBezierTo(root.dx + side * s * 0.35, root.dy - s * 0.05, root.dx, root.dy + s * 0.06),
            paint);
      }
    }
    c.drawOval(body, paint);
    c.drawCircle(head, s * 0.2, paint);
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.translate(head.dx + side * s * 0.08, head.dy - s * 0.12);
      c.rotate(side * (0.15 + ears + (side > 0 ? twitch : 0)));
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-s * 0.055, -s * 0.38, s * 0.11, s * 0.4), Radius.circular(s * 0.05)),
          paint);
      c.restore();
    }
    // the eyes, blinking now and then
    if (s >= 18) {
      final color = paint.color;
      final dark = color.computeLuminance() < 0.25;
      final eye = Paint()..color = (dark ? _glow : _ink).withValues(alpha: color.a);
      final shut = beat % 3.7 < 0.14;
      for (final side in const [-1.0, 1.0]) {
        final e = head + Offset(side * s * 0.075, -s * 0.02);
        if (shut) {
          c.drawRect(Rect.fromCenter(center: e, width: s * 0.06, height: s * 0.012 + 0.6), eye);
        } else {
          c.drawCircle(e, s * 0.028 + 0.4, eye);
        }
      }
    }
  }

  void hill(double top, Paint paint) {
    c.drawPath(
        Path()
          ..moveTo(0, _h)
          ..lineTo(0, top + 18)
          ..quadraticBezierTo(_w * 0.45, top - 14, _w, top + 22)
          ..lineTo(_w, _h)
          ..close(),
        paint);
  }

  void oakTree(Offset base, double s, Paint paint) {
    c.drawPath(
        Path()
          ..moveTo(base.dx - s * 0.12, base.dy)
          ..lineTo(base.dx - s * 0.07, base.dy - s * 0.55)
          ..lineTo(base.dx + s * 0.07, base.dy - s * 0.55)
          ..lineTo(base.dx + s * 0.14, base.dy)
          ..close(),
        paint);
    for (final (dx, dy, r) in const [(0.0, -0.8, 0.33), (-0.3, -0.62, 0.24), (0.3, -0.64, 0.26), (-0.12, -0.98, 0.2), (0.18, -0.95, 0.2)]) {
      c.drawCircle(base + Offset(dx * s, dy * s), r * s, paint);
    }
  }

  void moon(Offset centre, double r, {double bite = 0}) {
    c.drawCircle(centre, r * 1.8, glow(0.35));
    c.drawCircle(centre, r, glow());
    c.drawCircle(centre, r, stroke(_ink, 1.2, 0.6));
    if (bite > 0) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
      c.drawCircle(centre + Offset(r * 2 * (1 - bite), -r * 0.3 * (1 - bite)), r * 1.02, ink());
      c.restore();
    }
  }

  void stars(int n, int seed, double alpha) {
    for (var i = 0; i < n; i++) {
      final p = Offset(hash01(seed + i) * _w, hash01(seed + 40 + i) * _h * 0.6);
      final tw = 0.5 + 0.5 * math.sin(t * 3 + i);
      c.drawCircle(p, 1 + hash01(seed + 80 + i), glow(alpha * tw));
    }
  }

  void arc(Offset centre, double radius, double band, double alpha, {double progress = 1}) {
    for (var k = 0; k < 6; k++) {
      // Mama's rainbows, faded to old paint
      final color = Color.lerp(Palette.rainbow[k], _wash, 0.45)!;
      c.drawArc(Rect.fromCircle(center: centre, radius: radius - k * band), math.pi, math.pi * progress, false,
          stroke(color, band + 0.5, alpha));
    }
  }

  // ---------- the scenes ----------

  void _wings() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), wash(0.25));
    // a rainbow trail fading below the bunny
    for (var k = 0; k < 6; k++) {
      final color = Color.lerp(Palette.rainbow[k], _wash, 0.4)!;
      final path = Path()..moveTo(150 + k * 4.0, 170);
      for (var y = 170.0; y > 100; y -= 6) {
        path.lineTo(150 + k * 4.0 + math.sin(y * 0.08 - t * 4) * 4, y);
      }
      c.drawPath(path, stroke(color, 4.4, 0.6));
    }
    final bob = math.sin(t * 2.5) * 5;
    bunny(Offset(160, 108 + bob), 70, ink(), wings: true, flap: 0.5 + 0.5 * math.sin(t * 9));
    // something like a question mark, fading in and out
    final q = 0.4 + 0.4 * math.sin(t * 1.5);
    c.drawCircle(Offset(214, 40 + bob), 2.5, ink(q));
    c.drawArc(Rect.fromCircle(center: Offset(214, 26 + bob), radius: 7), math.pi, math.pi * 1.4, false, stroke(_ink, 2, q));
  }

  void _oak() {
    stars(6, 3, 0.5);
    hill(118, wash());
    oakTree(const Offset(170, 128), 96, ink());
    // the burrow door among the roots, its window glowing and flickering
    final flicker = 0.7 + 0.3 * math.sin(t * 7) * math.sin(t * 3.1);
    c.drawOval(const Rect.fromLTWH(150, 116, 34, 22), ink());
    c.drawOval(const Rect.fromLTWH(157, 120, 20, 14), glow(flicker));
    // fireflies drifting up
    for (var i = 0; i < 6; i++) {
      final y = 140 - ((t * 14 + i * 23) % 90);
      final x = 120 + i * 18 + math.sin(t * 2 + i) * 8;
      c.drawCircle(Offset(x, y), 1.8, glow(0.8 * (0.5 + 0.5 * math.sin(t * 5 + i))));
    }
  }

  void _seven() {
    c.drawRect(const Rect.fromLTWH(0, 128, _w, 42), wash());
    const sizes = [62.0, 58.0, 55.0, 52.0, 48.0, 44.0, 30.0];
    var x = 40.0;
    for (var i = 0; i < 7; i++) {
      final s = sizes[i];
      final hop = i == 6 ? math.max(0.0, math.sin(t * 6)) * 14 : math.max(0.0, math.sin(t * 2 + i)) * 2;
      bunny(Offset(x, 132 - hop), s, ink(i == 6 ? 1 : 0.8));
      x += s * 0.62 + 6;
    }
    // the smallest one is pointed out
    final a = at(1, 1.8);
    c.drawPath(
        Path()
          ..moveTo(x - 20, 46)
          ..lineTo(x - 26, 58)
          ..lineTo(x - 14, 58)
          ..close(),
        ink(a));
  }

  void _rainbows() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), wash(0.35));
    // Mama painting an arch on the burrow wall
    final paint = at(0.2, 3.2);
    arc(const Offset(150, 140), 95, 8, 0.9, progress: paint);
    final angle = math.pi + math.pi * paint;
    final brush = const Offset(150, 140) + Offset(math.cos(angle) * 75, math.sin(angle) * 75);
    bunny(Offset(brush.dx + 18, 160), 66, ink());
    c.drawLine(brush, Offset(brush.dx + 12, brush.dy + 26), stroke(_ink, 2.5));
    // little ones watching
    bunny(const Offset(270, 166), 34, ink(0.8));
    bunny(const Offset(292, 166), 28, ink(0.8));
  }

  void _sunset() {
    final sink = at(0, 5);
    c.drawCircle(Offset(160, 104 + sink * 40), 34, glow());
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(0, 90.0 + i * 9), Offset(_w, 90.0 + i * 9), stroke(_wash, 2, 0.5));
    }
    hill(120, ink());
    bunny(const Offset(96, 136), 34, ink());
  }

  void _longShadows() {
    hill(122, wash());
    oakTree(const Offset(230, 134), 90, ink());
    // the oak's shadow stretching further than any shadow should
    final grow = at(0, 5);
    c.drawPath(
        Path()
          ..moveTo(222, 134)
          ..lineTo(240, 134)
          ..lineTo(240 - 60 - 200 * grow, 168)
          ..lineTo(190 - 60 - 200 * grow, 168)
          ..close(),
        ink(0.75));
    bunny(const Offset(130, 132), 44, ink()); // Papa
    bunny(const Offset(104, 132), 26, ink()); // Pip
  }

  void _door() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), wash(0.4));
    // a round door, boarded shut
    c.drawCircle(const Offset(160, 96), 56, ink(0.85));
    c.drawCircle(const Offset(160, 96), 50, wash());
    for (final y in const [74.0, 98.0, 122.0]) {
      c.drawRect(Rect.fromLTWH(104, y, 112, 8), ink());
    }
    // the dark creeping in under it and rising, slow, like water
    final rise = at(0.5, 6);
    final level = 170 - rise * 80;
    final path = Path()..moveTo(0, _h);
    for (var x = 0.0; x <= _w; x += 8) {
      path.lineTo(x, level + math.sin(x * 0.06 + t * 2) * 4);
    }
    path
      ..lineTo(_w, _h)
      ..close();
    c.drawPath(path, ink(0.9));
  }

  void _hiding() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), wash(0.3));
    arc(const Offset(90, 170), 80, 7, 0.8);
    arc(const Offset(250, 170), 60, 6, 0.6);
    // Pip curled up small, trembling
    final shake = math.sin(t * 30) * 0.8;
    c.drawOval(Rect.fromLTWH(140 + shake, 138, 40, 26), ink());
    c.drawCircle(Offset(176 + shake, 140), 10, ink());
    c.drawOval(Rect.fromLTWH(170 + shake, 128, 18, 6), ink());
    // calls from the dark, rings fading out
    for (var i = 0; i < 3; i++) {
      final age = (t * 0.8 + i / 3) % 1;
      c.drawCircle(const Offset(300, 40), 10 + age * 60, stroke(_ink, 2, 0.6 * (1 - age)));
    }
  }

  void _constellation() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.85));
    stars(30, 11, 0.7);
    // the Bunny drawing itself, star by star
    const pts = [Offset(140, 40), Offset(146, 74), Offset(166, 36), Offset(168, 74), Offset(132, 94), Offset(155, 112), Offset(180, 94)];
    const lines = [(0, 1), (2, 3), (1, 3), (1, 4), (4, 5), (5, 6), (6, 3)];
    final shown = at(0.3, 4) * lines.length;
    for (var i = 0; i < lines.length; i++) {
      final f = (shown - i).clamp(0.0, 1.0);
      if (f <= 0) continue;
      final (a, b) = lines[i];
      c.drawLine(pts[a], Offset.lerp(pts[a], pts[b], f)!, stroke(_glow, 1.4, 0.8));
    }
    for (final p in pts) {
      c.drawCircle(p, 2.6, glow());
    }
    // Mama and Pip below, looking up
    hill(140, ink());
    bunny(const Offset(60, 150), 40, wash());
    bunny(const Offset(86, 150), 22, wash());
  }

  void _sevenShadows() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), wash(0.5));
    // an empty room; seven shadows on the wall, swaying
    var x = 36.0;
    const sizes = [60.0, 56.0, 53.0, 50.0, 46.0, 42.0, 28.0];
    for (var i = 0; i < 7; i++) {
      final sway = math.sin(t * 1.3 + i) * 2;
      final alpha = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(t * 2 + i * 1.7));
      bunny(Offset(x + sway, 150), sizes[i], ink(alpha));
      x += sizes[i] * 0.6 + 7;
    }
    c.drawRect(const Rect.fromLTWH(0, 150, _w, 20), ink(0.7));
  }

  void _crying() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.8));
    stars(14, 5, 0.5);
    moon(const Offset(240, 46), 26);
    hill(126, wash(0.9));
    bunny(const Offset(110, 136), 40, ink(), ears: 0.5);
    // tears falling
    for (var i = 0; i < 2; i++) {
      final f = (t * 0.9 + i * 0.5) % 1;
      c.drawCircle(Offset(114 + i * 6, 112 + f * 22), 1.8, glow(1 - f));
    }
    // the moon answers: three pulses
    final answer = at(3, 3.4);
    if (answer > 0) c.drawCircle(const Offset(240, 46), 26 + 18 * (0.5 + 0.5 * math.sin(t * 4)), stroke(_glow, 2, answer * 0.7));
  }

  void _moonCalls() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.85));
    moon(const Offset(160, 40), 30);
    // a beam reaching down to the little bunny
    final reach = at(0.5, 2.5);
    c.drawPath(
        Path()
          ..moveTo(146, 60)
          ..lineTo(174, 60)
          ..lineTo(174 + 30 * reach, 60 + 100 * reach)
          ..lineTo(146 - 30 * reach, 60 + 100 * reach)
          ..close(),
        glow(0.22));
    bunny(Offset(160, 160 - 6 * reach), 34, wash());
  }

  void _runes() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.8));
    // the tunnel walls; an old painted rainbow turning into runes
    c.drawRect(const Rect.fromLTWH(0, 0, 70, _h), wash(0.6));
    c.drawRect(const Rect.fromLTWH(250, 0, 70, _h), wash(0.6));
    final turn = at(1, 4);
    arc(const Offset(35, 100), 30, 4, 1 - turn);
    final rune = stroke(Palette.glimmer, 2, turn);
    c.drawLine(const Offset(35, 70), const Offset(35, 110), rune);
    c.drawLine(const Offset(23, 82), const Offset(35, 70), rune);
    c.drawLine(const Offset(47, 82), const Offset(35, 70), rune);
    arc(const Offset(285, 70), 26, 3.5, 0.9);
    bunny(Offset(160, 130 + math.sin(t * 2.5) * 4), 44, wash(), wings: true, flap: 0.5 + 0.5 * math.sin(t * 9));
  }

  void _bargain() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.85));
    moon(const Offset(160, 36), 26);
    // wings drifting down from the moon onto the bunny
    final fall = at(0.3, 3);
    final wingsAt = Offset.lerp(const Offset(160, 60), const Offset(160, 118), fall)!;
    if (fall < 1) {
      for (final side in const [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: wingsAt + Offset(side * 18, 0), width: 26, height: 12), glow(0.9));
      }
    }
    bunny(const Offset(160, 160), 44, wash(), wings: fall >= 1, flap: 0.5 + 0.5 * math.sin(t * 9));
    // a thin thread from the bunny back to the moon: the price
    if (fall >= 1) c.drawLine(const Offset(160, 120), const Offset(160, 62), stroke(_glow, 0.8, 0.5 + 0.3 * math.sin(t * 3)));
  }

  void _forgetting() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.85));
    moon(const Offset(250, 34), 22);
    bunny(const Offset(110, 156), 50, wash(), wings: true, flap: 0.3);
    // scraps of memory torn away and drawn up into the moon
    for (var i = 0; i < 7; i++) {
      final f = (t * 0.35 + i / 7) % 1;
      final p = Offset.lerp(const Offset(110, 110), const Offset(250, 34), f)! + Offset(0, math.sin(f * 9 + i) * 14);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(f * 6 + i);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: 10 * (1 - f * 0.6), height: 7 * (1 - f * 0.6)),
          Paint()..color = _paper.withValues(alpha: 1 - f * 0.5));
      c.restore();
    }
  }

  void _brothers() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.92));
    // the Hollow Ones in the dark: stitched plush bunnies, one eye glowing, grinning
    for (var i = 0; i < 4; i++) {
      final x = 50.0 + i * 74;
      final y = 74.0 + math.sin(t * 1.2 + i) * 4 + (hash01((t * 1.3).floor() * 5 + i) < 0.15 ? 2 : 0);
      final body = Paint()..color = Palette.hollow;
      c.drawOval(Rect.fromCenter(center: Offset(x - 7, y - 26), width: 8, height: 26), body); // upright ear
      c.save();
      c.translate(x + 7, y - 16);
      c.rotate(0.9); // the torn ear, flopped over
      c.drawOval(const Rect.fromLTWH(-4, -16, 8, 16), body);
      c.restore();
      c.drawCircle(Offset(x, y), 20, body);
      c.drawCircle(Offset(x, y), 20, stroke(Palette.hollowRim, 1.6, 0.8));
      final open = (t + i) % 3.5 > 0.15;
      c.drawOval(Rect.fromCenter(center: Offset(x - 7, y - 3), width: 7, height: open ? 7 : 1), Paint()..color = Palette.hollowEye);
      c.drawLine(Offset(x + 4, y - 6), Offset(x + 10, y), stroke(Palette.hollowRim, 1.4));
      c.drawLine(Offset(x + 10, y - 6), Offset(x + 4, y), stroke(Palette.hollowRim, 1.4));
      c.drawArc(Rect.fromCenter(center: Offset(x, y + 4), width: 22, height: 12), 0.2, math.pi - 0.4, false,
          stroke(_paper, 1.4, 0.8));
    }
    bunny(const Offset(160, 166), 34, wash());
  }

  void _eclipse() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink());
    stars(20, 21, 0.4);
    final eaten = at(0.3, 5);
    c.drawCircle(const Offset(160, 80), 46 + 10 * eaten, Paint()..color = Palette.corona.withValues(alpha: 0.25 * eaten));
    moon(const Offset(160, 80), 40, bite: eaten);
  }

  void _feeding() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink());
    moon(const Offset(160, 70), 36, bite: 1);
    c.drawCircle(const Offset(160, 70), 40, stroke(Palette.corona, 3, 0.7));
    // little lights (all that was lost) pulled spiralling in
    for (var i = 0; i < 12; i++) {
      final f = (t * 0.3 + i / 12) % 1;
      final a = i * 0.9 + f * 5;
      final r = 140 * (1 - f) + 36;
      c.drawCircle(const Offset(160, 70) + Offset(math.cos(a) * r, math.sin(a) * r * 0.6), 2.4 * (1 - f) + 0.6,
          glow(1 - f * 0.6));
    }
  }

  void _falling() {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink(0.85));
    // falling, over and over: down the frame and back in at the top
    final f = (t * 0.6) % 1;
    c.save();
    c.translate(160, -30 + f * 230);
    c.rotate(f * math.pi * 2);
    bunny(const Offset(0, 20), 40, wash(), wings: true, flap: 1);
    c.restore();
    // a memory torn off at each fall
    final scrap = Offset(160 + f * 60, 60 - f * 50);
    c.drawRect(Rect.fromCenter(center: scrap, width: 9, height: 6), Paint()..color = _paper.withValues(alpha: 1 - f));
  }

  void _name() {
    // light breaking through: the dark pulls back from the middle
    final open = at(0.3, 3);
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), ink());
    c.drawCircle(const Offset(160, 90), 30 + 140 * open, glow(0.9));
    c.drawCircle(const Offset(160, 90), 20 + 100 * open, Paint()..color = _paper);
    arc(const Offset(160, 170), 70 * open + 1, 6, open);
    bunny(Offset(160, 130 - 10 * math.sin(t * 2)), 64, ink(), wings: true, flap: 0.5 + 0.5 * math.sin(t * 8));
  }
}
