import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import 'memory_scenes.dart';

/// Pip's lost memories, drifting in the dark behind the walls: old photographs of the memory
/// scenes, and torn scraps of paper with pieces of Pip's sentences on them. From twilight on
/// they come from the realms the run has reached, and the higher it goes the more corrupted
/// they are: torn corners, slipping slices, faces scratched out, letters breaking up, and in
/// the Void red ghost copies and burnt edges. Memories not found yet are blacked out, full of
/// static, their words unreadable. Part of the backdrop (field coordinates).
class MemoryDrift extends Component with HasGameReference<GoingUpGame> {
  MemoryDrift({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;
  final List<_Keepsake> _photos = [], _scraps = [];
  final Map<MemoryScene, Picture> _pictures = {};

  static const double _photoW = 104, _photoH = 56;
  static const _glyphs = '#?!&+-:0123456789';

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 4; i++) {
      _photos.add(_spawn(GameState.maxHeight * (i / 4)));
    }
    for (var i = 0; i < 3; i++) {
      _scraps.add(_spawn(GameState.maxHeight * ((i + 0.5) / 3)));
    }
  }

  _Keepsake _spawn(double y) {
    final realm = game.state.realm;
    final choices = [for (final m in Memories.all) if (m.realm <= realm) m];
    final memory = choices[_rng.nextInt(choices.length)];
    final words = memory.text.split(' ');
    final start = _rng.nextInt(math.max(1, words.length - 2));
    return _Keepsake(
      memory: memory,
      x: 110 + _rng.nextDouble() * (GameState.width - 220), // mostly where the tunnel lets it show
      y: y,
      tilt: (_rng.nextDouble() - 0.5) * 0.5,
      sway: _rng.nextDouble() * 6.3,
      depth: 0.03 + _rng.nextDouble() * 0.04,
      seed: _rng.nextInt(1000),
      words: words.skip(start).take(2 + _rng.nextInt(2)).join(' '),
    );
  }

  @override
  void update(double dt) {
    final state = game.state;
    final step = math.min(dt, 0.05);
    for (final list in [_photos, _scraps]) {
      for (var i = 0; i < list.length; i++) {
        final k = list[i];
        k.y += (6 + state.speed * k.depth) * step;
        if (k.y > state.height + 90) list[i] = _spawn(-90);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final st = game.stages;
    final shown = 1 - st.candy; // from twilight on
    if (shown <= 0.01) return;
    final corruption = (0.1 * st.wallpaper + 0.4 * st.rust + 0.7 * st.hollow + st.abyss).clamp(0.0, 1.0);
    final t = game.state.time;
    final found = game.state.memories;
    for (final k in _photos) {
      _photo(canvas, k, found.contains(k.memory.id), shown, corruption, t);
    }
    for (final k in _scraps) {
      _scrap(canvas, k, found.contains(k.memory.id), shown, corruption, t);
    }
  }

  Picture _picture(MemoryScene scene) => _pictures.putIfAbsent(scene, () {
        final recorder = PictureRecorder();
        drawMemoryScene(Canvas(recorder), const Rect.fromLTWH(0, 0, _photoW, _photoH), scene, 3.5);
        return recorder.endRecording();
      });

  void _photo(Canvas canvas, _Keepsake k, bool found, double shown, double c, double t) {
    final frame = (t * 8).floor();
    final alpha = 0.5 * shown * (c > 0.6 && hash01(frame * 3 + k.seed) < 0.08 * c ? 0.3 : 1); // it flickers
    canvas.save();
    canvas.translate(k.x, k.y);
    canvas.rotate(k.tilt + math.sin(t * 0.4 + k.sway) * 0.05);
    canvas.translate(-_photoW / 2 - 5, -_photoH / 2 - 5);
    canvas.saveLayer(const Rect.fromLTWH(-12, -12, _photoW + 34, _photoH + 44), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));

    // the card, with a corner torn away once things start falling apart
    final card = Path()..addRect(const Rect.fromLTWH(0, 0, _photoW + 10, _photoH + 22));
    if (c > 0.2 && hash01(k.seed + 1) < 0.7) {
      final bite = 16 + 18 * hash01(k.seed + 2);
      final right = hash01(k.seed + 3) < 0.5;
      final x = right ? _photoW + 10.0 : 0.0, dir = right ? -1.0 : 1.0;
      card.fillType = PathFillType.evenOdd;
      card.addPolygon([Offset(x, 0), Offset(x + dir * bite, 0), Offset(x + dir * bite * 0.4, bite * 0.5), Offset(x, bite * 0.9)], true);
    }
    canvas.clipPath(card);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _photoW + 10, _photoH + 22), Paint()..color = const Color(0xFFD8CBB0));
    const image = Rect.fromLTWH(5, 5, _photoW, _photoH);

    if (found) {
      // the picture, slipping sideways in slices as it breaks up
      final slices = c > 0.3 ? 4 : 1;
      for (var i = 0; i < slices; i++) {
        final band = Rect.fromLTWH(image.left, image.top + image.height * i / slices, image.width, image.height / slices);
        final slip = hash01(frame + i * 13 + k.seed) < c * 0.5 ? (hash01(frame * 7 + i) - 0.5) * 16 * c : 0.0;
        canvas.save();
        canvas.clipRect(band);
        canvas.translate(image.left + slip, image.top);
        canvas.drawPicture(_picture(k.memory.scene));
        canvas.restore();
      }
      // a red ghost copy, slipped out of place (the void)
      if (c > 0.7) {
        canvas.save();
        canvas.clipRect(image);
        canvas.saveLayer(image, Paint()
          ..colorFilter = const ColorFilter.mode(Color(0xFFFF2030), BlendMode.modulate)
          ..color = Color.fromRGBO(0, 0, 0, 0.35 * c));
        canvas.translate(image.left + 3 + math.sin(t * 9) * 2, image.top);
        canvas.drawPicture(_picture(k.memory.scene));
        canvas.restore();
        canvas.restore();
      }
      // the faces scratched out
      if (c > 0.5 && hash01(k.seed + 4) < 0.6) {
        final scratch = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFF8A1020).withValues(alpha: 0.85);
        final cx = image.left + image.width * (0.3 + 0.4 * hash01(k.seed + 5)), cy = image.top + image.height * 0.5;
        final scribble = Path()..moveTo(cx - 12, cy - 8);
        for (var i = 0; i < 9; i++) {
          scribble.lineTo(cx + (i.isEven ? 12 : -12) + hash01(k.seed + i) * 4, cy - 8 + i * 2.2);
        }
        canvas.drawPath(scribble, scratch);
      }
    } else {
      // forgotten: blacked out, full of static, a question scratched into it
      canvas.drawRect(image, Paint()..color = const Color(0xFF0E0A0C));
      final dot = Paint();
      for (var i = 0; i < 70; i++) {
        final h = hash01(frame * 101 + i + k.seed);
        dot.color = Color.fromRGBO(220, 210, 200, 0.15 + 0.4 * h);
        canvas.drawRect(
            Rect.fromLTWH(image.left + hash01(i * 7 + frame + k.seed) * image.width,
                image.top + hash01(i * 11 + frame * 3) * image.height, 1.5, 1.5),
            dot);
      }
      PixelFont.drawCentered(canvas, '?', image.center.dx, image.center.dy - 10, 3, const Color(0xFFB8AFA4));
    }

    // burnt edges in the void
    if (c > 0.8) {
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, _photoW + 10, _photoH + 22),
          Paint()
            ..shader = Gradient.radial(const Offset((_photoW + 10) / 2, (_photoH + 22) / 2), _photoW * 0.75, [
              const Color(0x00000000),
              const Color(0xFF1A0204).withValues(alpha: (c - 0.8) * 4),
            ], [
              0.6,
              1
            ]));
    }
    // a caption scrawled on the white border, breaking up with the rest
    _glitched(canvas, found ? k.words : '- - -', (_photoW + 10) / 2, _photoH + 9, 1.2, const Color(0xFF3A2A1E), c, t, k.seed);
    canvas.restore();
    canvas.restore();
  }

  void _scrap(Canvas canvas, _Keepsake k, bool found, double shown, double c, double t) {
    final text = found ? k.words : List.filled(k.words.length, '-').join();
    final w = PixelFont.widthOf(text, 1.5) + 18;
    canvas.save();
    canvas.translate(k.x, k.y);
    canvas.rotate(k.tilt * 0.6 + math.sin(t * 0.5 + k.sway) * 0.06);
    canvas.saveLayer(Rect.fromLTWH(-w / 2 - 8, -20, w + 16, 40), Paint()..color = Color.fromRGBO(0, 0, 0, 0.45 * shown));
    drawPaper(canvas, Rect.fromLTWH(-w / 2, -12, w, 24), k.seed);
    _glitched(canvas, text, 0, -5, 1.5, Palette.ink, c, t, k.seed);
    canvas.restore();
    canvas.restore();
  }

  /// [text] centred at [x], its letters breaking up the more [c]orrupted it is: some swap for
  /// stray symbols, some jump aside in red, flickering from frame to frame.
  void _glitched(Canvas canvas, String text, double x, double y, double px, Color color, double c, double t, int seed) {
    final left = x - PixelFont.widthOf(text, px) / 2;
    final frame = (t * 10).floor();
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      var at = Offset(left + i * 6 * px, y);
      var ink = color;
      final roll = hash01(i * 31 + frame * 7 + seed);
      if (ch != ' ' && roll < 0.3 * c) {
        ch = _glyphs[(hash01(i + frame * 3) * _glyphs.length).floor() % _glyphs.length];
        ink = const Color(0xFFB0283C);
        at += Offset((hash01(i + frame) - 0.5) * 4 * c, (hash01(i * 2 + frame) - 0.5) * 4 * c);
      }
      PixelFont.draw(canvas, ch, at.dx, at.dy, px, ink);
    }
  }

  @override
  void onRemove() {
    for (final picture in _pictures.values) {
      picture.dispose();
    }
    _pictures.clear();
    super.onRemove();
  }
}

class _Keepsake {
  _Keepsake({
    required this.memory,
    required this.x,
    required this.y,
    required this.tilt,
    required this.sway,
    required this.depth,
    required this.seed,
    required this.words,
  });

  final Memory memory;
  final double x, tilt, sway, depth;
  final int seed;
  final String words;
  double y;
}
