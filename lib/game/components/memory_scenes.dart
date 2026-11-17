import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;

import '../drawing.dart';
import '../memories.dart';
import '../palette.dart';
import '../pixel_font.dart';
import '../sprites.dart';

/// The memory scenes: little paper theatres, like a pop-up book. Layers of cut paper unfold
/// into place, then the family (drawn from Pip's own sprite, in sepia) acts the memory out in
/// two or three beats. Each is drawn in a [sceneSize] box; [t] is seconds since the memory
/// started playing, so the scene's layers rise from about one second in.
///
/// The deeper the realm a memory belongs to, the more corrupted it plays ([corruptionOf]): its
/// picture slips in slices, a red ghost copy slides out of place, and the film burns.

const sceneSize = Size(340, 330);
const double _w = 340, _h = 330;

/// How corrupted [memory] plays: clean in the bright sky, broken in the Void. The very last
/// memory, when Pip remembers its name, comes through almost clear.
double corruptionOf(Memory memory) =>
    memory.scene == MemoryScene.name ? 0.1 : const [0.0, 0.25, 0.45, 0.7, 0.95][memory.realm];

/// Draws [memory]'s scene at time [t] into [rect], with film wear and its corruption.
/// [corruption] overrides how broken it plays (the drifting photos use their own).
void drawMemoryScene(Canvas canvas, Rect rect, Memory memory, double t, Sprites art, {double? corruption}) {
  final recorder = PictureRecorder();
  final g = Canvas(recorder);
  _Scene(g, t, art).draw(memory.scene);
  _filmWear(g, t, corruption ?? corruptionOf(memory));
  final picture = recorder.endRecording();
  final c = corruption ?? corruptionOf(memory);

  canvas.save();
  canvas.clipRect(rect);
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / _w, rect.height / _h);
  if (c <= 0) {
    canvas.drawPicture(picture);
  } else {
    // the picture slips sideways in bands, now and then
    const bands = 6;
    final frame = (t * 9).floor();
    for (var i = 0; i < bands; i++) {
      final slip = hash2(frame + i * 13.0, 3) < c * 0.45 ? (hash2(frame * 7.0 + i, 5) - 0.5) * 30 * c : 0.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, _h * i / bands, _w, _h / bands + 0.5));
      canvas.translate(slip, 0);
      canvas.drawPicture(picture);
      canvas.restore();
    }
    if (c > 0.6) {
      // a red ghost copy, slipped out of place
      canvas.saveLayer(
          const Rect.fromLTWH(-10, 0, _w + 20, _h),
          Paint()
            ..colorFilter = const ColorFilter.mode(Color(0xFFC0202C), BlendMode.srcIn)
            ..color = Color.fromRGBO(0, 0, 0, 0.13 + 0.07 * math.sin(t * 9)));
      canvas.translate(4 + math.sin(t * 7) * 2, 0);
      canvas.drawPicture(picture);
      canvas.restore();
    }
  }
  canvas.restore();
  picture.dispose();
}

/// Old film: a flickering exposure, grain, the odd scratch, burns in corrupted memories, and
/// a vignette.
void _filmWear(Canvas g, double t, double corruption) {
  final paint = Paint();
  paint.color = Color.fromRGBO(40, 25, 12, 0.04 + 0.05 * hash2((t * 12).floorToDouble(), 9));
  g.drawRect(const Rect.fromLTWH(0, 0, _w, _h), paint);
  final grain = (t * 24).floorToDouble();
  for (var i = 0; i < 90; i++) {
    paint.color = hash2(i.toDouble(), grain) < 0.5 ? const Color(0x40FFF0D2) : const Color(0x401E120A);
    g.drawRect(Rect.fromLTWH(hash2(i * 3.0, grain) * _w, hash2(i * 7.0, grain) * _h, 1, 1), paint);
  }
  final scratch = (t * 6).floorToDouble();
  if (hash2(scratch, 4) < 0.5) {
    final x = hash2(scratch, 5) * _w;
    g.drawLine(Offset(x, 0), Offset(x + 3, _h), Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x591E120A));
  }
  if (corruption > 0.5) {
    for (var i = 0; i < 3; i++) {
      final cycle = t * 0.5 + i / 3, life = cycle - cycle.floorToDouble(), n = cycle.floorToDouble();
      final x = hash2(i.toDouble(), n) * _w, y = hash2(i + 4.0, n) * _h, r = 6 + life * 30;
      g.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..shader = Gradient.radial(Offset(x, y), r, [
              Color.fromRGBO(255, 245, 220, 0.8 * (1 - life)),
              Color.fromRGBO(200, 90, 30, 0.5 * (1 - life)),
              const Color(0x00C85A1E),
            ], [
              0,
              0.6,
              1
            ]));
    }
  }
  g.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = Gradient.radial(const Offset(_w / 2, _h / 2), _w * 0.75, [
          const Color(0x001E120A),
          const Color(0x991E120A),
        ], [
          0.45,
          1
        ]));
}

const _ink = Color(0xFF24170E);
const _paperLight = Color(0xFFEAD9B0);
const _glow = Color(0xFFF7EBC8);
const _redInk = Color(0xFF7A1E22);

class _Scene {
  _Scene(this.c, this.t, this.art);

  final Canvas c;
  final double t;
  final Sprites art;
  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final _pixels = Paint()..filterQuality = FilterQuality.none;

  double get cam => math.sin(t * 0.3) * 6;
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

  // ---------- pieces of the paper theatre ----------

  /// A cut-paper layer: a soft drop shadow under the shape, and a faint light rim on it.
  void cutout(Path path, Color fill, {double shadow = 0.35, bool rim = true}) {
    c.save();
    c.translate(3, 4);
    c.drawPath(path, _fill..color = Color.fromRGBO(30, 18, 10, shadow));
    c.restore();
    c.drawPath(path, _fill..color = fill);
    if (rim) {
      c.drawPath(
          path,
          _line
            ..strokeWidth = 1
            ..color = const Color(0x2EFFF0D2));
    }
  }

  /// Pop-up book entrance: layer [i] rises and unfolds into place, the layers one after
  /// another from about one second in.
  void popup(int i, void Function() draw, {double start = 1.0}) {
    final e = Curves.easeOutBack.transform(ramp(t, start + i * 0.16, start + i * 0.16 + 0.65).clamp(0.0, 1.0));
    if (e <= 0.001) return;
    final squash = math.max(0.05, e);
    c.save();
    c.translate(0, _h * (1 - e) * 0.5 + _h * (1 - squash));
    c.scale(1, squash);
    draw();
    c.restore();
  }

  void sky(Color top, Color bottom) {
    c.drawRect(
        const Rect.fromLTWH(-200, -200, _w + 400, _h + 400),
        Paint()..shader = Gradient.linear(Offset.zero, const Offset(0, _h), [top, bottom]));
  }

  Path hills(double y, double amp, double seed) {
    final p = Path()
      ..moveTo(-20, _h + 10)
      ..lineTo(-20, y);
    for (var x = -20.0; x <= _w + 20; x += 10) {
      p.lineTo(x, y + math.sin(x * 0.02 + seed) * amp + math.sin(x * 0.051 + seed * 2) * amp * 0.4);
    }
    return p
      ..lineTo(_w + 20, _h + 10)
      ..close();
  }

  Path grass(double depth) {
    final p = Path()..moveTo(-20, _h + 10);
    for (var x = -20.0; x <= _w + 20; x += 7) {
      p
        ..lineTo(x, _h - 6 - hash2(x, 2) * depth)
        ..lineTo(x + 3.5, _h - 2);
    }
    return p
      ..lineTo(_w + 20, _h + 10)
      ..close();
  }

  Path oakTree(double x, double ground, double s) {
    final tree = Path()
      ..moveTo(x - 18 * s, ground)
      ..lineTo(x - 9 * s, ground - 90 * s)
      ..lineTo(x + 9 * s, ground - 90 * s)
      ..lineTo(x + 18 * s, ground)
      ..close();
    for (final (dx, dy, r) in const [(0.0, -130.0, 46.0), (-34.0, -110.0, 34.0), (36.0, -112.0, 36.0), (-12.0, -160.0, 30.0), (20.0, -156.0, 30.0)]) {
      tree.addOval(Rect.fromCircle(center: Offset(x + dx * s, ground + dy * s), radius: r * s));
    }
    return tree;
  }

  void moonDisc(Offset at, double r, {double eaten = 0, Color face = const Color(0xFFEFE0BB)}) {
    c.drawCircle(
        at,
        r * 2.6,
        Paint()
          ..shader = Gradient.radial(at, r * 2.6, [
            Color.fromRGBO(240, 220, 170, 0.35 * (1 - eaten)),
            const Color(0x00F0DCAA),
          ]));
    if (eaten > 0) {
      c.drawCircle(
          at,
          r * 1.7,
          Paint()
            ..shader = Gradient.radial(at, r * 1.7, [
              Color.fromRGBO(190, 30, 45, 0.9 * eaten),
              const Color(0x00BE1E2D),
            ], [
              0.55,
              1
            ]));
    }
    c.drawCircle(at, r, _fill..color = face);
    _fill.color = const Color(0x80A0825A);
    for (final (dx, dy, cr) in const [(-0.33, -0.22, 0.18), (0.26, 0.15, 0.24), (-0.11, 0.4, 0.11)]) {
      c.drawCircle(at + Offset(dx * r, dy * r), cr * r, _fill);
    }
    if (eaten > 0) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r + 0.5)));
      c.drawCircle(at + Offset(r * 2.2 * (1 - eaten), -r * 0.4 * (1 - eaten)), r * 1.05, _fill..color = const Color(0xFF0A0605));
      c.restore();
    }
  }

  void stars(int n, double seed, double alpha) {
    for (var i = 0; i < n; i++) {
      _fill.color = Color.fromRGBO(232, 216, 180, alpha * (0.4 + 0.6 * math.sin(t * 2 + i).abs()));
      c.drawRect(Rect.fromLTWH(hash2(i.toDouble(), seed) * _w, hash2(i.toDouble(), seed + 1) * _h * 0.7, 1.5, 1.5), _fill);
    }
  }

  /// A rainbow arch in faded paint, drawn [progress] of the way round.
  void rainbow(Offset base, double radius, double band, double alpha, {double progress = 1}) {
    for (var k = 0; k < 6; k++) {
      c.drawArc(
          Rect.fromCircle(center: base, radius: radius - k * band),
          math.pi,
          math.pi * progress,
          false,
          _line
            ..strokeWidth = band + 0.5
            ..color = Color.lerp(Palette.rainbow[k], const Color(0xFFB89A6E), 0.45)!.withValues(alpha: alpha));
    }
  }

  /// A bunny from Pip's sprite standing with its feet at ([x], [feet]), [px] per sprite pixel.
  /// [blink] closes its eyes, [flip] turns it to face left, [wings] flap with [flap].
  void bunny(BunnySprites sprites, double x, double feet, double px,
      {bool wings = false, double flap = 0, bool blink = false, bool flip = false, double alpha = 1, Color? eyeLid}) {
    c.save();
    c.translate(x, feet);
    if (flip) c.scale(-1, 1);
    if (alpha < 1) c.saveLayer(Rect.fromLTWH(-20 * px, -26 * px, 40 * px, 28 * px), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    void image(Image image, double dx, double dy) {
      c.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(dx * px, dy * px, image.width * px, image.height * px), _pixels);
    }

    if (wings) {
      final up = flap > 0.5;
      image(up ? sprites.wingUpLeft : sprites.wingDownLeft, -14, -12);
      image(up ? sprites.wingUpRight : sprites.wingDownRight, 7, -12);
    }
    image(sprites.bunny, -8, -25);
    if (blink) {
      _fill.color = eyeLid ?? const Color(0xFFC7A878);
      c.drawRect(Rect.fromLTWH(-5 * px, -15 * px, 2 * px, 2 * px), _fill);
      c.drawRect(Rect.fromLTWH(3 * px, -15 * px, 2 * px, 2 * px), _fill);
    }
    if (alpha < 1) c.restore();
    c.restore();
  }

  bool blinking(double offset) => (t + offset) % 3.4 < 0.12;

  // ---------- Rainbow Sky ----------

  void _wings() {
    sky(_paperLight, const Color(0xFFD3B88A));
    popup(0, () => cutout(_cloud(70, 90, 1.2), const Color(0xFFF2E6C6), shadow: 0.15));
    popup(1, () => cutout(_cloud(250, 60, 1), const Color(0xFFF2E6C6), shadow: 0.15));
    // Pip rises into the frame on the wings it doesn't remember getting
    final rise = Curves.easeOutCubic.transform(at(1.6, 3.4));
    final y = _h + 60 - rise * 230 + math.sin(t * 2.4) * 5;
    for (var k = 0; k < 6; k++) {
      final path = Path()..moveTo(170.0 - 12 + k * 4.4, _h + 20);
      for (var yy = _h + 20; yy > y; yy -= 6) {
        path.lineTo(170.0 - 12 + k * 4.4 + math.sin(yy * 0.06 - t * 4) * 5, yy);
      }
      c.drawPath(
          path,
          _line
            ..strokeWidth = 4.8
            ..color = Color.lerp(Palette.rainbow[k], const Color(0xFFB89A6E), 0.45)!);
    }
    // it looks one way, then the other
    final look = t > 4.6 && (t * 0.8).floor().isEven;
    bunny(art.memory, 170, y, 2.6, wings: true, flap: (t * 3) % 1, flip: look, blink: blinking(0));
    popup(2, () => cutout(_cloud(60, 270, 1.4), const Color(0xFFE8D7B0), shadow: 0.2), start: 1.2);
    if (t > 4.8) {
      final a = at(4.8, 5.4);
      PixelFont.draw(c, '?', 214, y - 86 - 6 * a, 3, _ink.withValues(alpha: a));
    }
  }

  Path _cloud(double x, double y, double s) {
    final p = Path();
    for (final (dx, dy, r) in const [(0.0, 0.0, 22.0), (24.0, -8.0, 26.0), (50.0, 0.0, 20.0), (26.0, 8.0, 22.0)]) {
      p.addOval(Rect.fromCircle(center: Offset(x + dx * s + cam * 0.3, y + dy * s), radius: r * s));
    }
    return p;
  }

  void _oak() {
    const ground = _h * 0.8;
    sky(_paperLight, const Color(0xFFCFB284));
    stars(8, 3, 0.5);
    popup(0, () => cutout(hills(_h * 0.55, 14, 1), const Color(0xFFBF9E6E), shadow: 0.2));
    popup(1, () {
      c.save();
      c.translate(cam * 0.4, 0);
      cutout(oakTree(_w * 0.42, ground, 1.15), const Color(0xFF5C4128), rim: false);
      // the burrow door: its window glows, then the door swings open and light spills out
      final open = at(3.2, 4.2);
      c.drawOval(Rect.fromCenter(center: Offset(_w * 0.42, ground - 12), width: 44, height: 30), _fill..color = _ink);
      final flicker = 0.65 + 0.35 * math.sin(t * 7) * math.sin(t * 3.1);
      c.drawOval(Rect.fromCenter(center: Offset(_w * 0.42, ground - 13), width: 26 + 14 * open, height: 18 + 8 * open),
          _fill..color = Color.fromRGBO(255, 214, 140, flicker));
      if (open > 0) {
        c.drawPath(
            Path()
              ..moveTo(_w * 0.42 - 16, ground - 4)
              ..lineTo(_w * 0.42 + 16, ground - 4)
              ..lineTo(_w * 0.42 + 70, ground + 30)
              ..lineTo(_w * 0.42 - 70, ground + 30)
              ..close(),
            _fill..color = Color.fromRGBO(255, 214, 140, 0.25 * open));
        // little ones passing the light
        for (var i = 0; i < 3; i++) {
          final x = _w * 0.42 - 14 + ((t - 4.2) * 18 + i * 10) % 28;
          bunny(art.memoryShade, x, ground - 4, 0.7);
        }
      }
      c.restore();
    });
    popup(2, () => cutout(hills(ground, 4, 5), const Color(0xFF8F6C45)));
    popup(3, () => cutout(grass(16), const Color(0xFF2C1D12), shadow: 0.5));
    // fireflies
    for (var i = 0; i < 7; i++) {
      final y = _h - 40 - ((t * 14 + i * 23) % 140);
      _fill.color = Color.fromRGBO(255, 230, 160, 0.8 * (0.5 + 0.5 * math.sin(t * 5 + i)) * at(1.5, 2.5));
      c.drawCircle(Offset(60.0 + i * 36 + math.sin(t * 2 + i) * 8, y), 2, _fill);
    }
  }

  void _seven() {
    const ground = _h * 0.8;
    const xs = [0.36, 0.46, 0.55, 0.64, 0.73, 0.82, 0.92];
    const sizes = [1.9, 1.8, 1.75, 1.7, 1.6, 1.5, 1.15];
    final focus = at(5.4, 7.2);
    final pip = _w * xs[6];
    // the camera leans in on the smallest
    c.translate(pip, ground - 30);
    c.scale(1 + 0.18 * focus);
    c.translate(-pip - (pip - _w / 2) * 0.12 * focus, -(ground - 30));
    sky(_paperLight, const Color(0xFFCFB284));
    c.drawCircle(Offset(_w * 0.8, _h * 0.22), 26, _fill..color = const Color(0xB3FAECC8));
    popup(0, () => cutout(hills(_h * 0.5, 14, 1), const Color(0xFFBF9E6E), shadow: 0.2));
    popup(1, () => cutout(oakTree(_w * 0.22, ground, 1), const Color(0xFF5C4128), rim: false));
    popup(2, () => cutout(hills(ground, 4, 5), const Color(0xFF8F6C45)));
    // the seven hop in from the right, one after another
    for (var i = 0; i < 7; i++) {
      final start = 2.4 + i * 0.32, k = ((t - start) / 0.9).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final x = _w + 50 + (_w * xs[i] - _w - 50) * Curves.easeOutCubic.transform(k);
      var hop = (math.sin(k * math.pi * 2)).abs() * 16 * (1 - k * 0.6);
      if (i == 6 && t > 5.6 && t < 6.9) hop = math.max(0.0, math.sin((t - 5.6) * 7)) * 10;
      bunny(art.memory, x + cam * 0.6, ground + 4 - hop, sizes[i], blink: blinking(i * 0.7));
    }
    popup(3, () => cutout(grass(16), const Color(0xFF2C1D12), shadow: 0.5));
    // an ink circle drawn around the smallest: this one is Pip
    if (t > 5.3) {
      final k = at(5.3, 6.4);
      final ring = Path();
      for (var a = 0.0; a <= math.pi * 2.15 * k; a += 0.08) {
        final r = 30 + math.sin(a * 3) * 2;
        final p = Offset(pip + cam * 0.6 + math.cos(a - 1.4) * r, ground - 18 + math.sin(a - 1.4) * r * 1.1);
        a == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
      }
      c.drawPath(
          ring,
          _line
            ..strokeWidth = 2.2
            ..color = _redInk);
    }
  }

  void _rainbows() {
    const floor = _h * 0.82;
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFFC9AE84));
    popup(0, () => cutout(Path()..addRect(const Rect.fromLTWH(-20, floor, _w + 40, _h)), const Color(0xFF7A5A3A)));
    // Mama paints an arch on the burrow wall, stroke by stroke
    final paint = at(2.2, 5.2);
    rainbow(const Offset(_w * 0.42, floor - 10), 120, 9, 0.95, progress: paint);
    final angle = math.pi + math.pi * paint;
    final brush = const Offset(_w * 0.42, floor - 10) + Offset(math.cos(angle) * 90, math.sin(angle) * 90);
    bunny(art.memory, brush.dx + 24, floor + 2, 2.6, blink: blinking(0.3));
    c.drawLine(brush, brush + const Offset(16, 30), _line
      ..strokeWidth = 2.5
      ..color = _ink);
    // the little ones hop over to watch
    for (var i = 0; i < 2; i++) {
      final k = Curves.easeOutCubic.transform(at(4.6 + i * 0.4, 5.6 + i * 0.4));
      if (k <= 0) continue;
      bunny(art.memory, _w + 30 - k * (90 - i * 26), floor + 2 - (math.sin(k * math.pi * 3)).abs() * 10 * (1 - k), 1.4 - i * 0.2,
          blink: blinking(1.0 + i));
    }
  }

  // ---------- Twilight ----------

  void _sunset() {
    sky(const Color(0xFFE6C796), const Color(0xFFC78E6A));
    final sink = Curves.easeInOut.transform(at(1.6, 6.5));
    c.drawCircle(Offset(_w * 0.55, _h * 0.48 + sink * 120), 40, _fill..color = const Color(0xFFF7DEA8));
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(0, _h * 0.42 + i * 10), Offset(_w, _h * 0.42 + i * 10), _line
        ..strokeWidth = 2
        ..color = const Color(0x40B07850));
    }
    popup(0, () => cutout(hills(_h * 0.62, 12, 2), const Color(0xFF8A5A3E), shadow: 0.25));
    popup(1, () => cutout(hills(_h * 0.76, 6, 7), const Color(0xFF4A2E1E)));
    bunny(art.memoryShade, _w * 0.25, _h * 0.77, 1.7, flip: true);
    if (t > 6.2) {
      final a = at(6.2, 7);
      c.drawCircle(const Offset(_w * 0.8, _h * 0.2), 2.2, _fill..color = _glow.withValues(alpha: a));
    }
  }

  void _longShadows() {
    const ground = _h * 0.72;
    sky(const Color(0xFFE2BE8C), const Color(0xFFB98260));
    popup(0, () => cutout(hills(ground, 5, 3), const Color(0xFF9A7048), shadow: 0.2));
    popup(1, () => cutout(oakTree(_w * 0.72, ground, 0.9), const Color(0xFF4A3020), rim: false));
    // the oak's shadow stretches further than any shadow should
    final grow = Curves.easeIn.transform(at(2.4, 6.5));
    c.drawPath(
        Path()
          ..moveTo(_w * 0.72 - 14, ground)
          ..lineTo(_w * 0.72 + 14, ground)
          ..lineTo(_w * 0.72 - 40 - 300 * grow, _h + 10)
          ..lineTo(_w * 0.72 - 110 - 300 * grow, _h + 10)
          ..close(),
        _fill..color = const Color(0xC0201208));
    // Papa turns to look at it; Pip hides behind him
    bunny(art.memory, _w * 0.36, ground + 2, 2.4, flip: t > 4.4, blink: blinking(0.2));
    bunny(art.memory, _w * 0.26, ground + 2, 1.4, blink: blinking(1.4));
  }

  void _door() {
    const floor = _h * 0.78;
    var shake = 0.0;
    for (final at in const [2.9, 3.4, 3.9]) {
      if (t > at && t < at + 0.25) shake += (0.25 - (t - at)) * 30;
    }
    final f = (t * 60).floorToDouble();
    c.translate((hash2(f, 1) - 0.5) * shake, (hash2(f, 2) - 0.5) * shake);
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFFB38A72));
    _fill.color = const Color(0x38462320);
    for (var x = -10.0; x < _w + 20; x += 18) {
      c.drawRect(Rect.fromLTWH(x + cam * 0.2, -20, 6, _h + 40), _fill);
    }
    popup(0, () {
      for (final (x, y, scratched) in const [(_w * 0.17, 70.0, false), (_w * 0.83, 64.0, true)]) {
        _portrait(Offset(x + cam * 0.3, y), scratched);
      }
    });
    final dx = _w / 2 + cam * 0.5, dy = floor - 70;
    const dr = 74.0;
    popup(1, () {
      final ring = Path()
        ..addArc(Rect.fromCircle(center: Offset(dx, dy), radius: dr), math.pi, math.pi)
        ..lineTo(dx + dr, floor)
        ..lineTo(dx - dr, floor)
        ..close();
      cutout(ring, const Color(0xFF4A2E1C));
      final inner = Path()
        ..addArc(Rect.fromCircle(center: Offset(dx, dy), radius: dr - 9), math.pi, math.pi)
        ..lineTo(dx + dr - 9, floor)
        ..lineTo(dx - dr + 9, floor)
        ..close();
      c.drawPath(inner, _fill..color = const Color(0xFF6A4630));
    });
    popup(2, () => cutout(Path()..addRect(const Rect.fromLTWH(-20, floor, _w + 40, _h)), const Color(0xFF5A3A26)));
    // the boards slam on, one, two, three
    for (final (at, rot, oy) in const [(2.9, -0.12, -40.0), (3.4, 0.08, 0.0), (3.9, -0.05, 40.0)]) {
      final k = Curves.easeOutBack.transform(((t - at) / 0.3).clamp(0.0, 1.0));
      if (t < at) continue;
      c.save();
      c.translate(dx, dy + oy + 20);
      c.rotate(rot);
      c.scale(1.6 - 0.6 * k);
      cutout(Path()..addRect(const Rect.fromLTWH(-dr - 16, -9, (dr + 16) * 2, 18)), const Color(0xFF7C5838), shadow: 0.45);
      c.restore();
      if (t - at < 0.6) {
        for (var j = 0; j < 10; j++) {
          final a = hash2(at, j.toDouble()) * math.pi * 2, d = (t - at) * 60 * (0.5 + hash2(j.toDouble(), at));
          c.drawCircle(Offset(dx + math.cos(a) * (dr + d), dy + oy + 20 + math.sin(a) * d * 0.4), 2,
              _fill..color = Color.fromRGBO(230, 210, 170, 0.6 * (1 - (t - at) / 0.6)));
        }
      }
    }
    // Pip by the wall, trembling once the dark comes; a candle that will go out
    bunny(art.memory, _w * 0.12 + (t > 4.6 ? math.sin(t * 40) * 0.8 : 0), floor + 2, 1.5, blink: t % 2.6 < 0.1);
    final out = at(6.6, 7.0);
    c.drawRect(const Rect.fromLTWH(_w * 0.88, floor - 22, 8, 22), _fill..color = const Color(0xFFE8D6AE));
    if (out < 1) {
      final fl = 0.8 + 0.2 * math.sin(t * 13);
      c.drawOval(Rect.fromCenter(center: Offset(_w * 0.88 + 4, floor - 30), width: 8, height: 16 * fl),
          _fill..color = Color.fromRGBO(255, 200, 110, (1 - out) * fl));
    }
    // the dark seeps under the door and rises, slow, like water; eyes open in it
    final seep = at(4.4, 8.5);
    if (seep > 0) {
      final level = floor + 4 - seep * _h * 0.5, spread = (seep * 3).clamp(0.0, 1.0) * (_w / 2 + 30);
      final water = Path()..moveTo(dx - spread, _h + 10);
      for (var x = dx - spread; x <= dx + spread; x += 6) {
        water.lineTo(x, level + math.sin(x * 0.07 + t * 2) * 3 + math.pow((x - dx).abs() / spread, 3) * 14);
      }
      water
        ..lineTo(dx + spread, _h + 10)
        ..close();
      c.drawPath(water, _fill..color = const Color(0xF00E0806));
      _eyesInDark(6.4, const [(0.4, 0.86), (0.62, 0.9), (0.75, 0.83)]);
    }
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = Color.fromRGBO(20, 10, 6, out * 0.35));
  }

  void _portrait(Offset at, bool scratched) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(math.sin(t * 0.8 + at.dx) * 0.03);
    c.drawLine(const Offset(0, -30), const Offset(-10, -12), _line
      ..strokeWidth = 0.8
      ..color = _ink);
    c.drawLine(const Offset(0, -30), const Offset(10, -12), _line);
    cutout(Path()..addOval(Rect.fromCenter(center: const Offset(0, 10), width: 36, height: 46)), const Color(0xFF6E4A22));
    c.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: 28, height: 38), _fill..color = const Color(0xFFCBB896));
    bunny(art.memory, 0, 26, 1.0);
    if (scratched) {
      for (var i = 0; i < 5; i++) {
        c.drawLine(Offset(-9, -2.0 + i * 3), Offset(9, 2.0 + i * 3), _line
          ..strokeWidth = 1.4
          ..color = _redInk);
      }
    }
    c.restore();
  }

  void _eyesInDark(double from, List<(double, double)> spots) {
    for (var i = 0; i < spots.length; i++) {
      final (ex, ey) = spots[i];
      if ((t + i * 1.3) % 3.1 < 0.15) continue;
      _fill.color = const Color(0xFFE8DDFF).withValues(alpha: 0.85 * at(from + i * 0.4, from + 0.6 + i * 0.4));
      for (final s in const [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(_w * ex + s * 5, _h * ey), width: 5.2, height: 3.6), _fill);
      }
    }
  }

  void _hiding() {
    const floor = _h * 0.8;
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFFC4A07E));
    popup(0, () {
      rainbow(const Offset(_w * 0.3, floor), 100, 8, 0.8);
      rainbow(const Offset(_w * 0.78, floor), 70, 6, 0.6);
    });
    popup(1, () => cutout(Path()..addRect(const Rect.fromLTWH(-20, floor, _w + 40, _h)), const Color(0xFF6A4A30)));
    // a dark doorway on the right where the calls come from
    c.drawRRect(RRect.fromRectAndCorners(const Rect.fromLTWH(_w * 0.86, floor - 110, 60, 110), topLeft: const Radius.circular(30)),
        _fill..color = const Color(0xFF140C08));
    // Pip curled up small in the corner, trembling
    bunny(art.memory, _w * 0.12 + math.sin(t * 30) * 0.7, floor + 2, 1.5, blink: true, eyeLid: const Color(0xFFC7A878));
    // the calls: "PIP?" from the dark, fading each time
    for (var i = 0; i < 3; i++) {
      final start = 2.4 + i * 1.6, age = t - start;
      if (age < 0 || age > 1.4) continue;
      final a = math.sin(math.pi * age / 1.4) * (1 - i * 0.25);
      PixelFont.draw(c, 'PIP?', _w * 0.66 - i * 20, floor - 80 - age * 10, 2, _ink.withValues(alpha: a));
    }
  }

  // ---------- Starfall (Ashfall) ----------

  void _constellation() {
    sky(const Color(0xFF1E140E), const Color(0xFF3A2818));
    stars(40, 11, 0.7);
    const pts = [Offset(150, 50), Offset(156, 96), Offset(180, 44), Offset(182, 96), Offset(140, 122), Offset(166, 146), Offset(194, 122)];
    const lines = [(0, 1), (2, 3), (1, 3), (1, 4), (4, 5), (5, 6), (6, 3)];
    final shown = at(1.8, 5) * lines.length;
    for (var i = 0; i < lines.length; i++) {
      final f = (shown - i).clamp(0.0, 1.0);
      if (f <= 0) continue;
      final (a, b) = lines[i];
      c.drawLine(pts[a], Offset.lerp(pts[a], pts[b], f)!, _line
        ..strokeWidth = 1.4
        ..color = const Color(0xCCF7EBC8));
    }
    for (final p in pts) {
      c.drawCircle(p, 2.8, _fill..color = _glow);
    }
    if (t > 5.4 && t < 6.4) {
      final k = (t - 5.4) / 1.0;
      final head = Offset(40 + k * 260, 30 + k * 60);
      c.drawLine(head - const Offset(40, 9), head, _line
        ..strokeWidth = 1.6
        ..color = _glow.withValues(alpha: math.sin(k * math.pi)));
    }
    popup(0, () => cutout(hills(_h * 0.78, 10, 4), const Color(0xFF120B07), shadow: 0.5, rim: false));
    bunny(art.memoryShade, _w * 0.28, _h * 0.8, 2.2);
    bunny(art.memoryShade, _w * 0.37, _h * 0.8, 1.3);
  }

  void _sevenShadows() {
    const floor = _h * 0.8;
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFFB79878));
    popup(0, () => cutout(Path()..addRect(const Rect.fromLTWH(-20, floor, _w + 40, _h)), const Color(0xFF6A4A30)));
    // seven shadows on the wall, swaying; one by one they turn to look at Pip
    const sizes = [2.6, 2.5, 2.4, 2.3, 2.15, 2.0, 1.4];
    var x = 30.0;
    for (var i = 0; i < 7; i++) {
      final turned = t > 5.0 + i * 0.25;
      bunny(art.memoryShade, x + math.sin(t * 1.3 + i) * 2, floor - 30, sizes[i],
          flip: turned, alpha: 0.4 + 0.25 * (0.5 + 0.5 * math.sin(t * 2 + i * 1.7)));
      x += sizes[i] * 16 + 4;
    }
    final k = Curves.easeOutCubic.transform(at(2.6, 4.4));
    bunny(art.memory, _w + 30 - k * 70, floor + 2, 1.5, blink: blinking(0.5));
  }

  void _crying() {
    // three nights: the sky goes dark three times
    final night = 0.5 + 0.5 * math.cos((t - 1) * 1.6);
    sky(Color.lerp(const Color(0xFF3A2818), const Color(0xFF120B07), night)!, const Color(0xFF2A1C12));
    stars(16, 5, 0.5 * night);
    moonDisc(const Offset(_w * 0.72, _h * 0.26), 30);
    final answer = at(5.6, 6.2);
    if (answer > 0) {
      c.drawCircle(const Offset(_w * 0.72, _h * 0.26), 30 + 24 * (0.5 + 0.5 * math.sin(t * 4)), _line
        ..strokeWidth = 2.5
        ..color = _glow.withValues(alpha: 0.7 * answer));
    }
    popup(0, () => cutout(hills(_h * 0.72, 12, 2), const Color(0xFF6E5034), shadow: 0.3));
    bunny(art.memory, _w * 0.32, _h * 0.74, 2.0, blink: true, eyeLid: const Color(0xFFC7A878));
    for (var i = 0; i < 2; i++) {
      final f = (t * 0.9 + i * 0.5) % 1;
      c.drawCircle(Offset(_w * 0.32 - 6 + i * 12, _h * 0.74 - 34 + f * 22), 1.8, _fill..color = _glow.withValues(alpha: 1 - f));
    }
    for (var n = 0; n < 3; n++) {
      if (t > 2 + n * 1.2) {
        _line
          ..strokeWidth = 2
          ..color = _glow.withValues(alpha: 0.8);
        c.drawLine(Offset(24.0 + n * 9, 24), Offset(24.0 + n * 9, 42), _line);
      }
    }
  }

  void _moonCalls() {
    sky(const Color(0xFF1A110C), const Color(0xFF2E2016));
    stars(20, 8, 0.5);
    moonDisc(const Offset(_w / 2, 58), 36);
    final reach = Curves.easeOut.transform(at(2.0, 4.0));
    c.drawPath(
        Path()
          ..moveTo(_w / 2 - 20, 80)
          ..lineTo(_w / 2 + 20, 80)
          ..lineTo(_w / 2 + 20 + 50 * reach, 80 + 210 * reach)
          ..lineTo(_w / 2 - 20 - 50 * reach, 80 + 210 * reach)
          ..close(),
        _fill..color = const Color(0x38F7EBC8));
    popup(0, () => cutout(hills(_h * 0.85, 6, 3), const Color(0xFF120B07), shadow: 0.5, rim: false));
    // Pip is lifted, just a little, into the light
    final lift = at(4.6, 7) * 26;
    bunny(art.memory, _w / 2, _h * 0.86 - lift + math.sin(t * 2) * (lift > 0 ? 2 : 0), 1.8, blink: blinking(0));
  }

  // ---------- Runelight (The Hollow) ----------

  void _runes() {
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF1A130E));
    popup(0, () {
      cutout(Path()..addRect(const Rect.fromLTWH(-20, -20, 90, _h + 40)), const Color(0xFF4A3A2C), shadow: 0.5);
      cutout(Path()..addRect(const Rect.fromLTWH(_w - 70, -20, 90, _h + 40)), const Color(0xFF4A3A2C), shadow: 0.5);
    });
    // Mama's painted rainbows, worn into scratched runes
    final turn = at(2.6, 5);
    for (final (x, y) in const [(35.0, 110.0), (_w - 35, 190.0), (35.0, 260.0)]) {
      rainbow(Offset(x, y), 26, 3.5, 1 - turn);
      _line
        ..strokeWidth = 2
        ..color = const Color(0xFFE6E0D2).withValues(alpha: 0.85 * turn);
      c.drawLine(Offset(x, y - 30), Offset(x, y + 4), _line);
      c.drawLine(Offset(x - 12, y - 18), Offset(x, y - 30), _line);
      c.drawLine(Offset(x + 12, y - 18), Offset(x, y - 30), _line);
    }
    bunny(art.memory, _w / 2, _h * 0.62 + math.sin(t * 2.5) * 5, 2.2, wings: true, flap: (t * 3) % 1, blink: blinking(0));
  }

  void _bargain() {
    sky(const Color(0xFF120B07), const Color(0xFF241810));
    stars(20, 9, 0.4);
    moonDisc(const Offset(_w / 2, 60), 34);
    // a pair of wings drifts down from the moon and settles on Pip
    final fall = Curves.easeInOut.transform(at(2.0, 4.6));
    final settled = fall >= 1;
    if (!settled) {
      final y = 100 + fall * 120;
      for (final s in const [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(_w / 2 + s * 24, y), width: 34, height: 14), _fill..color = const Color(0xE6F7EBC8));
      }
    }
    popup(0, () => cutout(hills(_h * 0.86, 5, 6), const Color(0xFF120B07), shadow: 0.5, rim: false));
    bunny(art.memory, _w / 2, _h * 0.86, 2.0, wings: settled, flap: (t * 3) % 1, blink: blinking(0.4));
    // a thread from Pip back up to the moon: the price
    if (settled) {
      c.drawLine(Offset(_w / 2, _h * 0.86 - 52), const Offset(_w / 2, 94), _line
        ..strokeWidth = 1
        ..color = const Color(0xFFC0303E).withValues(alpha: 0.5 + 0.3 * math.sin(t * 3)));
    }
  }

  void _forgetting() {
    sky(const Color(0xFF120B07), const Color(0xFF231710));
    moonDisc(const Offset(_w * 0.8, 52), 30);
    popup(0, () => cutout(hills(_h * 0.88, 5, 2), const Color(0xFF120B07), shadow: 0.5, rim: false));
    const from = Offset(_w * 0.3, _h * 0.6);
    bunny(art.memory, from.dx, from.dy + 40, 2.0, wings: true, flap: 0.3, blink: blinking(0.9));
    // little photographs torn away from Pip and drawn up into the moon
    for (var i = 0; i < 8; i++) {
      final f = ((t - 1.8) * 0.3 + i / 8) % 1;
      if (t < 1.8 + i * 0.4) continue;
      final p = Offset.lerp(from, const Offset(_w * 0.8, 52), f)! + Offset(0, math.sin(f * 9 + i) * 16);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(f * 6 + i);
      final s = 1 - f * 0.7;
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: 14 * s, height: 11 * s), _fill..color = _paperLight);
      c.drawRect(Rect.fromCenter(center: const Offset(0, -1), width: 10 * s, height: 6 * s), _fill..color = const Color(0xFF8A6A48));
      c.restore();
    }
  }

  void _brothers() {
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF1C130D));
    // a sliver of moonlight across the floor, so the family can be seen
    c.drawPath(
        Path()
          ..moveTo(_w * 0.35, -20)
          ..lineTo(_w * 0.65, -20)
          ..lineTo(_w * 0.95, _h + 20)
          ..lineTo(_w * 0.05, _h + 20)
          ..close(),
        _fill..color = const Color(0x24F7EBC8));
    // the Hollow Ones, wearing the family's faces, step closer
    final step = Curves.easeInOut.transform(at(2.4, 5.4));
    for (var i = 0; i < 4; i++) {
      final x = 50.0 + i * 80;
      final twitch = hash2((t * 1.3).floorToDouble() * 5, i.toDouble()) < 0.15 ? 2.0 : 0.0;
      bunny(art.memoryHollow, x + twitch, _h * 0.55 + step * 50, 2.2 + step * 0.5, wings: true, flap: (t * 2 + i) % 1);
      final glare = 0.4 + 0.3 * math.sin(t * 5 + i) + 0.3 * step;
      c.drawCircle(Offset(x - 4 * (2.2 + step * 0.5), _h * 0.55 + step * 50 - 14 * (2.2 + step * 0.5)), 7,
          _fill..color = Color.fromRGBO(255, 50, 50, 0.25 * glare));
    }
    popup(0, () => cutout(hills(_h * 0.9, 4, 6), const Color(0xFF1E140E), shadow: 0.5, rim: false));
    bunny(art.memory, _w / 2, _h * 0.96, 1.9, blink: blinking(0.2));
  }

  // ---------- The Void ----------

  void _eclipse() {
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF120B08));
    stars(40, 4, 0.6);
    moonDisc(Offset(_w * 0.6 + cam * 0.15, _h * 0.36), 60, eaten: at(2.6, 5.4));
    popup(0, () => cutout(hills(_h * 0.68, 18, 8), const Color(0xFF2A1D15), shadow: 0.5));
    popup(1, () {
      final crag = Path()
        ..moveTo(-20, _h + 10)
        ..lineTo(-20, _h * 0.74)
        ..lineTo(_w * 0.12, _h * 0.7)
        ..lineTo(_w * 0.26, _h * 0.76)
        ..lineTo(_w * 0.36, _h * 0.9)
        ..lineTo(_w * 0.4, _h + 10)
        ..close();
      cutout(crag, const Color(0xFF1C130E), shadow: 0.6);
      bunny(art.memory, _w * 0.17, _h * 0.71, 1.7, wings: true, flap: (t * 2) % 1);
    });
  }

  void _feeding() {
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF0E0806));
    const m = Offset(_w / 2, _h * 0.38);
    moonDisc(m, 52, eaten: 1);
    // little lights, everything lost, pulled in spiralling
    for (var i = 0; i < 30; i++) {
      final f = ((t - 1.6) * 0.35 + i / 30) % 1;
      final a = i * 1.7 + f * 6, r = (1 - f) * 240 + 52;
      c.drawCircle(m + Offset(math.cos(a) * r, math.sin(a) * r * 0.6), 2.6 * (1 - f) + 0.6,
          _fill..color = _glow.withValues(alpha: (1 - f) * at(1.6, 2.4)));
    }
    popup(0, () => cutout(hills(_h * 0.86, 8, 2), const Color(0xFF1A110C), shadow: 0.5, rim: false));
    bunny(art.memoryShade, _w * 0.2, _h * 0.87, 1.4, flip: true);
  }

  void _falling() {
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF120B08));
    stars(30, 6, 0.4);
    // Pip falls, over and over, a memory torn away each time
    final f = ((t - 1.4) * 0.45) % 1;
    if (t > 1.4) {
      c.save();
      c.translate(_w / 2 + math.sin(f * 4) * 30, -40 + f * (_h + 90));
      c.rotate(f * math.pi * 3);
      bunny(art.memory, 0, 30, 1.8, wings: true, flap: 1);
      c.restore();
      final scrap = Offset(_w / 2 + 30 + f * 60, 60 + f * (_h * 0.5) - f * f * 120);
      c.drawRect(Rect.fromCenter(center: scrap, width: 12, height: 9), _fill..color = _paperLight.withValues(alpha: 1 - f));
    }
  }

  void _name() {
    // light breaks through the dark from Pip
    final open = Curves.easeOutCubic.transform(at(2.2, 5.2));
    c.drawRect(const Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill..color = const Color(0xFF120B08));
    const centre = Offset(_w / 2, _h * 0.55);
    c.drawCircle(centre, 30 + 260 * open, Paint()
      ..shader = Gradient.radial(centre, 30 + 260 * open, [_glow, _paperLight, const Color(0x00EAD9B0)], [0, 0.7, 1]));
    rainbow(const Offset(_w / 2, _h * 0.98), 40 + 110 * open, 9, open);
    final wings = t > 3.6;
    bunny(art.memory, _w / 2, _h * 0.72 - 10 * math.sin(t * 2), 2.8, wings: wings, flap: (t * 2.5) % 1, blink: blinking(0.6));
  }
}
