import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../stages.dart';

/// The tunnel walls, drawn in world coordinates (x, -worldY) as anti-aliased curves through
/// the wall samples, so their edges are smooth. The walls turn into something else in each
/// realm (see [Stages]): candy pastel with sprinkles; the old burrow's peeling wallpaper with
/// family portraits, some with the faces scratched out; rusted mesh streaked with rust and
/// studded with bolts; black stone with roots, chalk scrawls and shadow hands reaching out;
/// and in the Void black flesh with pulsing red veins, watching eyes and teeth along the edge.
///
/// Everything is only drawn. The walls the bunny can hit stay where the game state says they
/// are: the warp and the teeth only ever reach a few units into the gap, so the tunnel can
/// look a little narrower than it is, never wider.
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
  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static const _chalk = Color(0xFFE6E0D2);
  static const _bone = Color(0xFFD9CCB4);
  static const _blood = Color(0xFFB01E30);

  /// Wall colour at world height [wy] for each realm's share in [stages].
  static Color wallColor(double wy, Stages stages) {
    final candy = HSLColor.fromAHSL(1, (wy * 0.1) % 360, 0.45, 0.68).toColor();
    if (stages.candy >= 1) return candy;
    final wave = math.sin(wy * 0.0017);
    return stages.mix(
      candy,
      HSLColor.fromAHSL(1, 335 + 18 * wave, 0.3, 0.4).toColor(), // dusty rose wallpaper
      HSLColor.fromAHSL(1, 18 + 8 * wave, 0.42, 0.22).toColor(), // rust
      HSLColor.fromAHSL(1, 140 + 30 * wave, 0.08, 0.11).toColor(), // black-green stone
      HSLColor.fromAHSL(1, 352, 0.4, 0.06).toColor(), // black flesh
    );
  }

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final walls = state.walls;
    if (walls.length < 2) return;
    final st = game.stages;
    final t = state.time;
    final warp = _warp(t);
    final left = [for (final s in walls) Offset(s.left + warp(s), -s.wy)];
    final right = [for (final s in walls) Offset(s.right - warp(s), -s.wy)];

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

    final top = state.distance + state.height;
    final colors = <Color>[], stops = <double>[];
    for (var k = 0; k <= 8; k++) {
      colors.add(wallColor(top - state.height * k / 8, st));
      stops.add(k / 8);
    }
    final fill = Paint()..shader = ui.Gradient.linear(Offset(0, -top), Offset(0, -state.distance), colors, stops);
    canvas.drawPath(leftFill, fill);
    canvas.drawPath(rightFill, fill);

    canvas.save();
    canvas.clipPath(Path()
      ..addPath(leftFill, Offset.zero)
      ..addPath(rightFill, Offset.zero));
    final view = Rect.fromLTRB(-10, -top - 20, GameState.width + 10, -state.distance + 20);
    if (st.wallpaper > 0.01) _wallpaperPattern(canvas, view, st.wallpaper);
    if (st.rust > 0.01) _mesh(canvas, view, st.rust);

    final bunny = Offset(state.bunnyX, -state.worldY(state.bunnyY));
    final cracks = math.max(st.rust, st.hollow) * 0.8;
    for (final s in walls) {
      if (s.wy < state.distance - 40 || s.wy > top + 40) continue;
      if (cracks > 0.01 && s.id % 7 == 0 && hash01(s.id + 61) < 0.7) _crack(canvas, s, t, cracks, Palette.runeViolet);
      if (st.abyss > 0.01 && s.id % 6 == 0 && hash01(s.id + 67) < 0.8) _crack(canvas, s, t, st.abyss, _blood, veins: true);
      if (st.hollow > 0.01 && s.id % 11 == 0) _root(canvas, s, st.hollow);
      if (st.hollow + st.abyss > 0.01 && s.id % 29 == 0) _hand(canvas, s, t, st.hollow + st.abyss);
      if (st.rust > 0.01 && s.id % 5 == 0) _bolts(canvas, s, st.rust);
      if (s.id % 3 != 0) continue;
      final roomRight = GameState.width - s.right;
      final spots = [
        if (s.left > 26) (5 + hash01(s.id) * (s.left - 24), -s.wy, s.id, s.left),
        if (roomRight > 26) (s.right + 19 + hash01(s.id + 5) * (roomRight - 24), -s.wy + 9, s.id + 11, roomRight),
      ];
      for (final (x, y, id, room) in spots) {
        final kind = hash01(id + 17);
        if (st.candy > 0.01) _sprinkle(canvas, x, y, id, st.candy);
        if (st.wallpaper > 0.01) {
          if (kind < 0.14 && room > 44) {
            _portrait(canvas, x, y, id, t, st.wallpaper);
          } else if (kind < 0.3) {
            _peel(canvas, x, y, id, st.wallpaper);
          }
        }
        if (st.rust > 0.01 && kind < 0.3) _rustStreak(canvas, x, y, id, st.rust);
        if (st.hollow > 0.01 && kind < 0.32) _scrawl(canvas, x, y, id, st.hollow);
        if (st.abyss > 0.01 && kind > 0.85) _eyes(canvas, x, y, id, st.abyss, t, bunny);
      }
    }
    canvas.restore();

    final leftEdge = Path()..moveTo(left.first.dx, left.first.dy);
    appendSmoothCurve(leftEdge, left);
    final rightEdge = Path()..moveTo(right.first.dx, right.first.dy);
    appendSmoothCurve(rightEdge, right);
    final glow = st.mix(Palette.rim.withValues(alpha: 0), const Color(0x00000000), const Color(0x22E07A3A),
        const Color(0x26C8CCC0), const Color(0x55D02040));
    if (glow.a > 0.01) {
      _rimGlow.color = glow;
      canvas.drawPath(leftEdge, _rimGlow);
      canvas.drawPath(rightEdge, _rimGlow);
    }
    _edgePaint.color = st.mix(Palette.ink, const Color(0xFF4A2A26), const Color(0xFF9A5530), const Color(0xFF8E9088),
        const Color(0xFF9E2236));
    canvas.drawPath(leftEdge, _edgePaint);
    canvas.drawPath(rightEdge, _edgePaint);
    if (st.abyss > 0.01) _teeth(canvas, left, right, st.abyss, t);
  }

  // ---------- candy ----------

  void _sprinkle(Canvas canvas, double x, double y, int id, double alpha) {
    final color = Palette.sprinkles[(hash01(id + 7) * Palette.sprinkles.length).floor() % Palette.sprinkles.length];
    _fill.color = color.withValues(alpha: alpha);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(hash01(id + 3) * math.pi);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -1.5, 9, 3), const Radius.circular(1.5)), _fill);
    canvas.restore();
  }

  // ---------- twilight: the old burrow's wallpaper ----------

  /// Faded stripes and a little diamond motif, fixed to the walls so they scroll with them.
  void _wallpaperPattern(Canvas canvas, Rect view, double alpha) {
    _fill.color = const Color(0xFF2A1220).withValues(alpha: 0.22 * alpha);
    for (var x = -8.0; x < GameState.width + 8; x += 18) {
      canvas.drawRect(Rect.fromLTWH(x, view.top, 6, view.height), _fill);
    }
    _fill.color = const Color(0xFFE8B8C0).withValues(alpha: 0.14 * alpha);
    final first = (view.top / 36).floorToDouble() * 36;
    final motif = Path();
    for (var y = first; y < view.bottom; y += 36) {
      for (var x = 6.0 + ((y / 36).round().isEven ? 0 : 9); x < GameState.width; x += 18) {
        motif
          ..moveTo(x, y - 5)
          ..lineTo(x + 3, y)
          ..lineTo(x, y + 5)
          ..lineTo(x - 3, y)
          ..close();
      }
    }
    canvas.drawPath(motif, _fill);
  }

  /// A patch where the wallpaper has peeled away: bare plaster with a curled, shadowed edge.
  void _peel(Canvas canvas, double x, double y, int id, double alpha) {
    final r = 7 + hash01(id + 2) * 9;
    final patch = Path();
    for (var i = 0; i < 7; i++) {
      final a = i * math.pi * 2 / 7;
      final d = r * (0.6 + 0.5 * hash01(id + 20 + i));
      final p = Offset(x + math.cos(a) * d, y + math.sin(a) * d * 1.3);
      i == 0 ? patch.moveTo(p.dx, p.dy) : patch.lineTo(p.dx, p.dy);
    }
    patch.close();
    _fill.color = const Color(0xFFB8A48C).withValues(alpha: 0.5 * alpha);
    canvas.drawPath(patch, _fill);
    canvas.drawPath(
        patch,
        _line
          ..strokeWidth = 1.5
          ..color = const Color(0xFF1E0E14).withValues(alpha: 0.6 * alpha));
  }

  /// A small oval family portrait hanging on a string: a bunny's silhouette. Some faces have
  /// been scratched out.
  void _portrait(Canvas canvas, double x, double y, int id, double t, double alpha) {
    canvas.save();
    canvas.translate(x, y - 14);
    canvas.rotate(math.sin(t * 0.8 + id) * 0.06 + (hash01(id + 4) - 0.5) * 0.2);
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0xFF140A0C).withValues(alpha: alpha);
    canvas.drawLine(const Offset(0, -8), const Offset(-6, 2), _line);
    canvas.drawLine(const Offset(0, -8), const Offset(6, 2), _line);
    final frame = Rect.fromCenter(center: const Offset(0, 14), width: 20, height: 26);
    _fill.color = const Color(0xFF6E4A22).withValues(alpha: alpha);
    canvas.drawOval(frame.inflate(2.5), _fill);
    _fill.color = const Color(0xFFCBB896).withValues(alpha: alpha);
    canvas.drawOval(frame, _fill);
    _fill.color = const Color(0xFF2A1A16).withValues(alpha: alpha);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 20), width: 10, height: 10), _fill);
    canvas.drawCircle(const Offset(0, 12), 4, _fill);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(side * 2.2, 5), width: 2.4, height: 8), _fill);
    }
    if (hash01(id + 9) < 0.5) {
      _line
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8A1020).withValues(alpha: alpha);
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(Offset(-6.0 + i * 2, 6), Offset(4.0 + i * 2, 16), _line);
      }
    }
    canvas.restore();
  }

  // ---------- ashfall: rusted mesh ----------

  /// Chain-link mesh over the walls.
  void _mesh(Canvas canvas, Rect view, double alpha) {
    const gap = 14.0;
    final mesh = Path();
    final h = view.height;
    for (var x = -h; x < GameState.width + h; x += gap) {
      final y0 = (view.top / gap).floorToDouble() * gap;
      mesh
        ..moveTo(x, y0)
        ..lineTo(x + h, y0 + h)
        ..moveTo(x + h, y0)
        ..lineTo(x, y0 + h);
    }
    canvas.drawPath(
        mesh,
        _line
          ..strokeWidth = 1.2
          ..color = const Color(0xFF120806).withValues(alpha: 0.45 * alpha));
  }

  /// Rust bleeding down the wall from a spot.
  void _rustStreak(Canvas canvas, double x, double y, int id, double alpha) {
    final length = 24 + hash01(id + 33) * 60;
    final width = 2 + hash01(id + 34) * 4;
    for (var i = 0; i < 3; i++) {
      _fill.color = const Color(0xFFA0461E).withValues(alpha: (0.45 - i * 0.13) * alpha);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - width / 2, y + i * length / 3, width, length / 3 + 1),
              Radius.circular(width / 2)),
          _fill);
    }
  }

  /// Bolts along the edge of a rusted plate.
  void _bolts(Canvas canvas, WallSample s, double alpha) {
    for (final x in [s.left - 9, s.right + 9]) {
      if (x < 4 || x > GameState.width - 4) continue;
      _fill.color = const Color(0xFF2A160E).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, -s.wy), 2.6, _fill);
      _fill.color = const Color(0xFFC07A48).withValues(alpha: 0.6 * alpha);
      canvas.drawCircle(Offset(x - 0.8, -s.wy - 0.8), 1, _fill);
    }
  }

  // ---------- the hollow: roots, chalk and hands ----------

  /// A twisted root crawling along the wall.
  void _root(Canvas canvas, WallSample s, double alpha) {
    final leftSide = hash01(s.id + 41) < 0.5;
    final room = leftSide ? s.left : GameState.width - s.right;
    if (room < 30) return;
    final x0 = leftSide ? s.left - 6 : s.right + 6;
    final dir = leftSide ? -1.0 : 1.0;
    final y0 = -s.wy;
    final path = Path()
      ..moveTo(x0, y0)
      ..cubicTo(x0 + dir * room * 0.4, y0 - 30, x0 + dir * room * 0.2, y0 - 70, x0 + dir * room * 0.8, y0 - 110);
    canvas.drawPath(
        path,
        _line
          ..strokeWidth = 6
          ..color = const Color(0xFF0A0806).withValues(alpha: 0.9 * alpha));
    canvas.drawPath(
        path,
        _line
          ..strokeWidth = 1.4
          ..color = const Color(0xFF5A4A38).withValues(alpha: 0.6 * alpha));
  }

  /// Chalk scrawled on the stone by a child: rainbows, the seven of them, tally marks, an eye.
  void _scrawl(Canvas canvas, double x, double y, int id, double alpha) {
    final wobble = (hash01(id + 50) - 0.5) * 0.3;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(wobble);
    _line
      ..strokeWidth = 1.4
      ..color = _chalk.withValues(alpha: 0.55 * alpha);
    switch ((hash01(id + 51) * 5).floor()) {
      case 0: // a rainbow
        for (var k = 0; k < 3; k++) {
          canvas.drawArc(Rect.fromCircle(center: const Offset(0, 6), radius: 10.0 - k * 3), math.pi, math.pi, false, _line);
        }
      case 1: // a little stick bunny
        canvas.drawCircle(const Offset(0, -2), 3.5, _line);
        canvas.drawLine(const Offset(-1.5, -5), const Offset(-2.5, -12), _line);
        canvas.drawLine(const Offset(1.5, -5), const Offset(2.5, -12), _line);
        canvas.drawLine(const Offset(0, 1.5), const Offset(0, 9), _line);
        canvas.drawLine(const Offset(0, 9), const Offset(-3, 13), _line);
        canvas.drawLine(const Offset(0, 9), const Offset(3, 13), _line);
      case 2: // seven tally marks, the last one crossed out
        for (var i = 0; i < 7; i++) {
          canvas.drawLine(Offset(-9.0 + i * 3, -5), Offset(-9.0 + i * 3, 5), _line);
        }
        _line.color = const Color(0xFFB02030).withValues(alpha: 0.7 * alpha);
        canvas.drawLine(const Offset(-11, 6), const Offset(11, -6), _line);
      case 3: // an eye
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 18, height: 9), _line);
        canvas.drawCircle(Offset.zero, 2.5, _line);
      default: // a spiral
        final spiral = Path()..moveTo(0, 0);
        for (var a = 0.0; a < math.pi * 5; a += 0.3) {
          spiral.lineTo(math.cos(a) * a * 0.8, math.sin(a) * a * 0.8);
        }
        canvas.drawPath(spiral, _line);
    }
    canvas.restore();
  }

  /// A long shadow arm reaching out of the wall toward the gap, fingers spread, slowly
  /// stretching and pulling back. It never reaches past the wall's edge.
  void _hand(Canvas canvas, WallSample s, double t, double alpha) {
    final leftSide = hash01(s.id + 71) < 0.5;
    final room = leftSide ? s.left : GameState.width - s.right;
    if (room < 50) return;
    final dir = leftSide ? 1.0 : -1.0; // toward the gap
    final reach = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 0.7 + s.id));
    final edge = leftSide ? s.left : s.right;
    final wrist = Offset(edge - dir * (6 + 26 * (1 - reach)), -s.wy);
    final shoulder = Offset(leftSide ? -10 : GameState.width + 10, -s.wy + 30);
    final arm = Path()
      ..moveTo(shoulder.dx, shoulder.dy - 7)
      ..quadraticBezierTo((shoulder.dx + wrist.dx) / 2, wrist.dy + 4, wrist.dx, wrist.dy - 2.5)
      ..lineTo(wrist.dx, wrist.dy + 2.5)
      ..quadraticBezierTo((shoulder.dx + wrist.dx) / 2, wrist.dy + 14, shoulder.dx, shoulder.dy + 7)
      ..close();
    _fill.color = const Color(0xFF050304).withValues(alpha: 0.9 * alpha);
    canvas.drawPath(arm, _fill);
    canvas.drawPath(
        arm,
        _line
          ..strokeWidth = 1
          ..color = const Color(0xFFB8B4A8).withValues(alpha: 0.35 * alpha));
    for (var i = 0; i < 4; i++) {
      final spread = (i - 1.5) * 0.35 + math.sin(t * 2 + i + s.id) * 0.08;
      final length = 11 + (i == 1 || i == 2 ? 4 : 0);
      final knuckle = wrist + Offset(dir * math.cos(spread) * length * 0.55, math.sin(spread) * length * 0.55);
      final tip = knuckle + Offset(dir * math.cos(spread * 1.6) * length * 0.5, math.sin(spread * 1.6) * length * 0.5);
      final finger = Path()
        ..moveTo(wrist.dx, wrist.dy)
        ..lineTo(knuckle.dx, knuckle.dy)
        ..lineTo(tip.dx, tip.dy);
      canvas.drawPath(
          finger,
          _line
            ..strokeWidth = 3
            ..color = const Color(0xFFB8B4A8).withValues(alpha: 0.3 * alpha));
      canvas.drawPath(
          finger,
          _line
            ..strokeWidth = 1.8
            ..color = const Color(0xFF050304).withValues(alpha: 0.95 * alpha));
    }
  }

  // ---------- the void: veins, eyes and teeth ----------

  /// Pale eyes in the dark wall, looking toward the bunny and blinking now and then. Smaller
  /// and paler than a Hollow One's, and only ever inside the walls.
  void _eyes(Canvas canvas, double x, double y, int id, double alpha, double time, Offset bunny) {
    final t = time + hash01(id + 41) * 9;
    final open = t % 4.3 > 0.15 && (t + 1.1) % 6.1 > 0.12;
    final look = bunny - Offset(x, y);
    final glance = look.distance > 1 ? look / look.distance * 0.9 : Offset.zero;
    for (final side in const [-1.0, 1.0]) {
      final e = Offset(x + side * 4.2, y);
      if (open) {
        _fill.color = Palette.voidEye.withValues(alpha: 0.85 * alpha);
        canvas.drawOval(Rect.fromCenter(center: e, width: 4.6, height: 3.2), _fill);
        _fill.color = const Color(0xFF6A0A14).withValues(alpha: alpha);
        canvas.drawCircle(e + glance, 1.1, _fill);
      } else {
        _fill.color = Palette.voidEye.withValues(alpha: 0.5 * alpha);
        canvas.drawRect(Rect.fromCenter(center: e, width: 4.6, height: 0.9), _fill);
      }
    }
  }

  /// Teeth along both edges, pointing a few units into the gap, gnashing a little.
  void _teeth(Canvas canvas, List<Offset> left, List<Offset> right, double alpha, double t) {
    final teeth = Path();
    for (var i = 1; i < left.length - 1; i += 2) {
      final size = 3 + 3 * hash01(i * 7) + math.sin(t * 3 + i) * 0.6;
      for (final (p, dir) in [(left[i], 1.0), (right[i], -1.0)]) {
        teeth
          ..moveTo(p.dx, p.dy - 3.5)
          ..lineTo(p.dx + dir * size * alpha, p.dy)
          ..lineTo(p.dx, p.dy + 3.5)
          ..close();
      }
    }
    _fill.color = _bone.withValues(alpha: alpha);
    canvas.drawPath(teeth, _fill);
  }

  // ---------- shared ----------

  /// How far the corruption pushes each drawn wall edge into the gap: a slow ripple from The
  /// Hollow on, with sharp glitch notches in the Void that flicker every few frames. Edges only
  /// ever move inward, so the gap can look a little narrower than it is, never wider.
  double Function(WallSample) _warp(double time) {
    final amount = ramp(game.corruption, 0.5, 1);
    if (amount <= 0) return (_) => 0;
    final deep = game.deep, frame = (time * 9).floor();
    return (s) {
      final ripple = (0.5 + 0.5 * math.sin(s.wy * 0.045 + time * 2.3)) * 3 * amount;
      final notch = deep > 0 && hash01(s.id ~/ 3 + frame * 17) < 0.06 * deep ? 5 * deep : 0.0;
      return ripple + notch;
    };
  }

  /// A crack running from the wall's edge back into the wall, with light seeping out of it.
  /// As [veins] in the Void, they're red and beat like a heart.
  void _crack(Canvas canvas, WallSample s, double time, double amount, Color light, {bool veins = false}) {
    final leftSide = hash01(s.id + 3) < 0.5;
    final room = leftSide ? s.left : GameState.width - s.right;
    if (room < 24) return;
    final dir = leftSide ? -1.0 : 1.0;
    final path = Path();
    var p = Offset(leftSide ? s.left : s.right, -s.wy);
    path.moveTo(p.dx, p.dy);
    final length = math.min(room - 6, 30 + hash01(s.id + 7) * (veins ? 90 : 50));
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      final dy = (hash01(s.id + 11 * i) - 0.5) * 16;
      p = Offset(p.dx + dir * length / steps, p.dy + dy);
      path.lineTo(p.dx, p.dy);
      if ((i == 2 || (veins && i == 4)) && hash01(s.id + 5 + i) < 0.7) {
        final b = p + Offset(dir * length * 0.3, (hash01(s.id + 9 + i) - 0.5) * 30);
        path
          ..lineTo(b.dx, b.dy)
          ..moveTo(p.dx, p.dy);
      }
    }
    final double beat;
    if (veins) {
      final phase = (time * 1.2) % 1; // lub-dub
      beat = 0.35 + 0.65 * math.max(math.exp(-phase * 14), 0.7 * math.exp(-(phase - 0.22).abs() * 14));
    } else {
      beat = 0.6 + 0.4 * math.sin(time * 5 + s.id);
    }
    _line
      ..strokeWidth = veins ? 6 : 5
      ..color = light.withValues(alpha: 0.2 * amount * beat);
    canvas.drawPath(path, _line);
    _line
      ..strokeWidth = veins ? 1.8 : 2.2
      ..color = (veins ? const Color(0xFF3A0008) : Palette.spaceVoid).withValues(alpha: 0.9 * amount);
    canvas.drawPath(path, _line);
    _line
      ..strokeWidth = 0.9
      ..color = light.withValues(alpha: 0.85 * amount * beat);
    canvas.drawPath(path, _line);
  }
}
