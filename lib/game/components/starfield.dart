import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import 'memory_drift.dart';

/// The space behind the tunnel, in the camera's backdrop (field coordinates): a field colour
/// and stars drifting past at different depths. As the climb passes through its realms, more
/// joins in: a sunset glow, a rising moon, constellations and shooting stars (twilight); a
/// brown haze that hides the stars and turns the moon a sick orange, with embers rising
/// (ashfall); grey-green murk and pale spores (the hollow); and in the Void black, with the
/// moon eclipsed into a ring of blood red. In front of it all drift Pip's lost memories, more
/// corrupted the higher it goes (see [MemoryDrift]). Broken shards of
/// the burrow, still showing painted rainbows, drift past more thickly the higher it goes.
class Starfield extends Component with HasGameReference<GoingUpGame> {
  /// [random] places the stars, motes and constellations and times the shooting stars (tests
  /// pass a seeded one).
  Starfield({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;
  final List<_Star> _stars = [];
  final List<_Mote> _motes = [];
  final List<_Figure> _figures = [];
  final List<_ShootingStar> _shooting = [];
  final List<_Shard> _shards = [];
  static const _maxShards = 12;
  final _paint = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _maxMotes = 26;

  /// Constellations: star positions around the figure's centre, and the lines joining them.
  static const _constellations = <(List<Offset>, List<(int, int)>)>[
    // the Bunny: two long ears over a round face
    (
      [Offset(-14, -34), Offset(-9, -6), Offset(6, -36), Offset(8, -6), Offset(-20, 10), Offset(-1, 24), Offset(20, 10)],
      [(0, 1), (2, 3), (1, 3), (1, 4), (4, 5), (5, 6), (6, 3)],
    ),
    // the Kite
    ([Offset(-24, -6), Offset(0, -28), Offset(24, -6), Offset(0, 18), Offset(4, 44)], [(0, 1), (1, 2), (2, 3), (3, 0), (3, 4)]),
    // the Ladle
    (
      [Offset(-40, -10), Offset(-22, -4), Offset(-6, -8), Offset(8, 2), Offset(12, 22), Offset(36, 26), Offset(38, 4)],
      [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)],
    ),
  ];

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
    for (var i = 0; i < _maxShards; i++) {
      _shards.add(_Shard(
        x: _rng.nextDouble() * GameState.width,
        y: _rng.nextDouble() * GameState.maxHeight,
        depth: 0.08 + _rng.nextDouble() * 0.14,
        size: 9 + _rng.nextDouble() * 14,
        spin: (_rng.nextDouble() - 0.5) * 1.2,
        seed: _rng.nextInt(1000),
      ));
    }
    add(MemoryDrift(random: _rng)); // Pip's lost memories, drifting in front of the sky
    for (var i = 0; i < _constellations.length; i++) {
      _figures.add(_Figure(i, x: _figureX(), y: (i + 0.3) * GameState.maxHeight / _constellations.length));
    }
  }

  double _figureX() => 80 + _rng.nextDouble() * (GameState.width - 160);

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
    for (final s in _shards) {
      s.y += dy * s.depth;
      s.rot += s.spin * step;
      if (s.y > state.height + 30) {
        s.y -= state.height + 60;
        s.x = _rng.nextDouble() * GameState.width;
      }
    }
    for (final f in _figures) {
      f.y += dy * 0.02; // far away: they barely move
      if (f.y > state.height + 60) {
        f.y -= state.height + 160;
        f.x = _figureX();
      }
    }

    // starfall: now and then a shooting star streaks across the sky
    for (final s in _shooting) {
      s.x += s.vx * step;
      s.y += s.vy * step;
      s.age += step;
    }
    _shooting.removeWhere((s) => s.age >= _ShootingStar.life);
    if (game.mood > 0.2 && game.mood < 0.38 && _shooting.length < 2 && _rng.nextDouble() < step * 0.35) {
      final dir = _rng.nextBool() ? 1.0 : -1.0;
      _shooting.add(_ShootingStar(
        x: dir > 0 ? 20 + _rng.nextDouble() * 180 : 200 + _rng.nextDouble() * 180,
        y: _rng.nextDouble() * state.height * 0.45,
        vx: dir * (260 + _rng.nextDouble() * 160),
        vy: 120 + _rng.nextDouble() * 100,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final mood = game.mood, deep = game.deep;
    final h = state.height, t = state.time;
    final st = game.stages;
    final sky = st.mix(Palette.space, const Color(0xFF15101E), const Color(0xFF231C18), const Color(0xFF101312),
        const Color(0xFF070103));
    canvas.drawRect(Rect.fromLTWH(0, 0, GameState.width, h), _paint..color = sky);
    final sunset = ramp(mood, 0.03, 0.18) * (1 - ramp(mood, 0.3, 0.5));
    if (sunset > 0) _sunset(canvas, sunset, h);

    if (mood > 0.02) _mist(canvas, mood, deep, t, h);

    final starColor = Color.lerp(Palette.star, Palette.starNight, mood)!;
    for (final s in _stars) {
      if (s.y > h + 4) continue;
      final twinkle = 0.5 + 0.5 * math.sin(t * (1.3 + mood) + s.phase);
      if (s.big) {
        _paint.color = starColor.withValues(alpha: 0.45 + 0.4 * twinkle);
        canvas.drawCircle(Offset(s.x, s.y), 1.7, _paint);
      } else {
        final base = (0.15 + s.depth * 1.2) * (1 - 0.7 * st.dread); // ash and fog swallow the faint ones
        _paint.color = starColor.withValues(alpha: (base * (1 - 0.6 * mood * (1 - twinkle))).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(s.x, s.y), 1.1, _paint);
      }
    }

    final figures = ramp(mood, 0.2, 0.34) * (1 - st.dread); // gone once the ash starts falling
    if (figures > 0) _drawConstellations(canvas, figures, t);
    for (final s in _shooting) {
      _shootingStar(canvas, s);
    }
    _moon(canvas, mood, deep, t, h);
    final shards = (_maxShards * ramp(game.corruption, 0.08, 0.7)).round();
    for (var i = 0; i < shards; i++) {
      _shard(canvas, _shards[i], mood);
    }

    // motes rising against the climb: glimmers, then embers in the ash, pale spores in the
    // fog, and sparks of blood red in the Void
    final mote = st.mix(Palette.glimmer, Palette.glimmer, const Color(0xFFFF7A3A), const Color(0xFFD8E4CC),
        const Color(0xFFFF3040));
    final shown = (_maxMotes * mood).round();
    for (var i = 0; i < shown; i++) {
      final m = _motes[i];
      final x = m.x + math.sin(t * 0.7 + m.phase) * 6;
      final glow = 0.5 + 0.5 * math.sin(t * 1.6 + m.phase * 2);
      _paint.color = mote.withValues(alpha: 0.08 * mood * (0.5 + glow));
      canvas.drawCircle(Offset(x, m.y), 4.5, _paint);
      _paint.color = mote.withValues(alpha: 0.55 * mood * (0.4 + 0.6 * glow));
      canvas.drawCircle(Offset(x, m.y), 1.3, _paint);
    }
  }

  /// Twilight: a warm glow rising from below, amber at the bottom fading through rose.
  void _sunset(Canvas canvas, double fade, double h) {
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.25, GameState.width, h * 0.75),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h * 0.25), [
            Palette.sunsetAmber.withValues(alpha: 0.24 * fade),
            Palette.sunsetRose.withValues(alpha: 0.12 * fade),
            Palette.sunsetRose.withValues(alpha: 0),
          ], [
            0,
            0.45,
            1
          ]));
  }

  /// Big soft patches of violet and teal that drift slowly, thicker in the Void.
  void _mist(Canvas canvas, double mood, double deep, double time, double h) {
    final st = game.stages;
    final violet = st.mix(Palette.mistViolet, Palette.mistViolet, const Color(0xFF6A5040), const Color(0xFF5E625C),
        const Color(0xFF5A0F18));
    final teal = st.mix(Palette.mistTeal, Palette.mistTeal, const Color(0xFF4A3A30), const Color(0xFF4A524C),
        const Color(0xFF300810));
    final colors = [violet, teal, violet];
    for (var i = 0; i < colors.length; i++) {
      final cx = GameState.width * (0.2 + 0.3 * i) + math.sin(time * 0.05 + i * 2.1) * 70;
      final cy = h * (0.2 + 0.3 * i) + math.cos(time * 0.04 + i * 1.3) * 90;
      final r = 160.0 + 40 * i;
      final paint = Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
          colors[i].withValues(alpha: 0.18 * mood + 0.07 * deep),
          colors[i].withValues(alpha: 0),
        ]);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _drawConstellations(Canvas canvas, double fade, double t) {
    _line
      ..strokeWidth = 1
      ..shader = null
      ..color = Palette.starNight.withValues(alpha: 0.2 * fade);
    for (final f in _figures) {
      final (stars, lines) = _constellations[f.shape];
      final o = Offset(f.x, f.y);
      for (final (a, b) in lines) {
        canvas.drawLine(o + stars[a], o + stars[b], _line);
      }
      for (var i = 0; i < stars.length; i++) {
        final twinkle = 0.6 + 0.4 * math.sin(t * 2.2 + i * 1.7 + f.shape);
        _paint.color = Palette.starNight.withValues(alpha: 0.9 * fade * twinkle);
        canvas.drawCircle(o + stars[i], 1.7, _paint);
        _paint.color = Palette.starNight.withValues(alpha: 0.12 * fade * twinkle);
        canvas.drawCircle(o + stars[i], 4.5, _paint);
      }
    }
  }

  void _shootingStar(Canvas canvas, _ShootingStar s) {
    final p = s.age / _ShootingStar.life;
    final alpha = math.sin(math.pi * p) * game.mood.clamp(0.0, 1.0);
    final head = Offset(s.x, s.y);
    final tail = head - Offset(s.vx, s.vy) * 0.16;
    _line
      ..strokeWidth = 1.8
      ..shader = ui.Gradient.linear(tail, head, [Palette.starNight.withValues(alpha: 0), Palette.text.withValues(alpha: alpha)]);
    canvas.drawLine(tail, head, _line);
    _line.shader = null;
    _paint.color = Palette.text.withValues(alpha: alpha);
    canvas.drawCircle(head, 1.6, _paint);
  }

  /// A broken piece of the burrow wall: a jagged slab in the old pastel, darkening with the
  /// climb, with a band of painted rainbow across it.
  void _shard(Canvas canvas, _Shard s, double mood) {
    final corners = 5 + s.seed % 3;
    final path = Path();
    for (var i = 0; i < corners; i++) {
      final a = i * 2 * math.pi / corners + hash01(s.seed + i) * 0.8;
      final r = s.size * (0.6 + 0.4 * hash01(s.seed + 20 + i));
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.save();
    canvas.translate(s.x, s.y);
    canvas.rotate(s.rot);
    final pastel = HSLColor.fromAHSL(1, hash01(s.seed + 40) * 360, 0.4, 0.66).toColor();
    _paint.color = Color.lerp(pastel, const Color(0xFF2A2140), 0.35 + 0.5 * mood)!.withValues(alpha: 0.8);
    canvas.drawPath(path, _paint);
    canvas.save();
    canvas.clipPath(path);
    final band = s.size * 0.18;
    for (var k = 0; k < 3; k++) {
      _paint.color = Palette.rainbow[(s.seed + k * 2) % 6].withValues(alpha: 0.55 * (1 - 0.5 * mood));
      canvas.drawRect(Rect.fromLTWH(-s.size, (k - 1.5) * band, s.size * 2, band), _paint);
    }
    canvas.restore();
    _line
      ..strokeWidth = 1.2
      ..shader = null
      ..color = Palette.rim.withValues(alpha: 0.35 + 0.4 * mood);
    canvas.drawPath(path, _line);
    canvas.restore();
  }

  /// The moon rises through twilight. In the Void a shadow slides across it until only a
  /// glowing ring is left.
  void _moon(Canvas canvas, double mood, double deep, double t, double h) {
    final rise = ramp(mood, 0.15, 0.45);
    if (rise <= 0) return;
    const r = 40.0;
    final c = Offset(GameState.width * 0.6, h * (0.92 - 0.7 * rise));

    canvas.drawCircle(
        c,
        r * 3.2,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 3.2, [
            Palette.moonGlow.withValues(alpha: 0.2 * rise * (1 - 0.7 * deep)),
            Palette.moonGlow.withValues(alpha: 0),
          ]));
    if (deep > 0) {
      final pulse = 0.85 + 0.15 * math.sin(t * 1.3);
      canvas.drawCircle(
          c,
          r * 1.9,
          Paint()
            ..shader = ui.Gradient.radial(c, r * 1.9, [
              Palette.blood.withValues(alpha: 0.9 * deep * pulse),
              Palette.blood.withValues(alpha: 0.9 * deep * pulse),
              Palette.mistTeal.withValues(alpha: 0.25 * deep * pulse),
              Palette.blood.withValues(alpha: 0),
            ], [
              0,
              0.52,
              0.62,
              1
            ]));
    }
    // through the ash and fog the moon turns a sick, dim orange
    final face = Color.lerp(Palette.moon, const Color(0xFFC8906E), game.stages.dread * 0.8)!;
    canvas.drawCircle(c, r, _paint..color = face.withValues(alpha: rise));
    _paint.color = Palette.moonShade.withValues(alpha: 0.55 * rise);
    for (final (dx, dy, cr) in const [(-14.0, -10.0, 8.0), (12.0, 6.0, 10.0), (-6.0, 18.0, 5.0), (18.0, -16.0, 4.0)]) {
      canvas.drawCircle(c + Offset(dx, dy), cr, _paint);
    }
    if (deep > 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r + 0.5)));
      final shadow = c + Offset(r * 2.1 * (1 - deep), -r * 0.5 * (1 - deep));
      canvas.drawCircle(shadow, r * 1.04, _paint..color = Palette.spaceVoid);
      canvas.restore();
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

class _Figure {
  _Figure(this.shape, {required this.x, required this.y});

  final int shape;
  double x, y;
}

class _ShootingStar {
  _ShootingStar({required this.x, required this.y, required this.vx, required this.vy});

  static const double life = 0.8;
  double x, y, age = 0;
  final double vx, vy;
}

class _Shard {
  _Shard({required this.x, required this.y, required this.depth, required this.size, required this.spin, required this.seed});

  double x, y, rot = 0;
  final double depth, size, spin;
  final int seed;
}
