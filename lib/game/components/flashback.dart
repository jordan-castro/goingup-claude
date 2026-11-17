import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import 'memory_scenes.dart';

/// Plays a memory as a flashback, from the memories book on the home screen (never during a
/// run). Ink bleeds out from the memory that was tapped, with splatter and drips, and soaks
/// away from the middle to leave an old page. On it a paper-theatre scene unfolds and acts the
/// memory out, and the words type themselves out in the game's letters, breaking up in the
/// deeper realms. A tap finishes the words; the next sets the page alight, and it burns away
/// from the edges with embers rising. Field coordinates, over the book.
class FlashbackPlayer extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;
  static const double _inkIn = 0.95, _typeFrom = 2.0, _lettersPerSecond = 28, _burn = 1.4;

  Memory? memory;
  double age = 0;
  double? _typedAt, _burnAt;
  Offset _from = const Offset(_w / 2, 400);
  Picture? _paper;
  double _paperHeight = 0;

  bool get isOpen => memory != null;

  /// The words are all out (typed, or skipped to the end).
  bool get typed => _typedAt != null || age >= _typeFrom + (memory?.text.length ?? 0) / _lettersPerSecond;

  bool get burning => _burnAt != null;

  /// Starts [memory], the ink spreading from [from] (field units).
  void play(Memory memory, Offset from) {
    this.memory = memory;
    age = 0;
    _typedAt = _burnAt = null;
    _from = from;
    game.state.markWatched(memory);
    game.sfx.play(const SoundCue(Sfx.memory));
  }

  /// A tap: finishes the words, then sets the page alight. Taps while the ink is still
  /// spreading are ignored.
  void press() {
    if (!isOpen || age < 0.8 || burning) return;
    if (!typed) {
      _typedAt = age;
    } else {
      _burnAt = age;
    }
  }

  @override
  void update(double dt) {
    if (!isOpen) return;
    age += dt;
    if (_burnAt != null && age - _burnAt! >= _burn) memory = null;
  }

  // ---------- layout (field units) ----------

  Rect get page {
    final top = game.safeTop + 26;
    return Rect.fromLTRB(16, top, _w - 16, game.state.height - game.safeBottom - 18);
  }

  /// The scene, with the words under it, sits in the middle of the page below the caption.
  Rect get scene {
    final p = page;
    final height = math.min(sceneSize.height, p.height * 0.5);
    final m = memory;
    final lines = m == null ? 0 : PixelFont.wrap(game.strings.memory(m), 25).length;
    final block = height + 30 + lines * 22;
    final top = p.top + 58 + math.max(0.0, (p.height - 58 - 60 - block) / 2);
    return Rect.fromLTWH(30, top, sceneSize.width, height);
  }

  // ---------- drawing ----------

  @override
  void render(Canvas canvas) {
    final memory = this.memory;
    if (memory == null) return;
    final h = game.state.height;
    final burnP = _burnAt == null ? 0.0 : ((age - _burnAt!) / _burn).clamp(0.0, 1.0);
    Path? remaining;
    if (burnP > 0) {
      // the page burns away from its edges: what's left is a ragged, shrinking blob
      final reach = math.sqrt(_w * _w / 4 + h * h * 0.3); // from the middle to the far corners
      remaining = noisyBlob(Offset(_w / 2, h * 0.45), (1 - burnP) * reach * 1.1, age, rough: 0.45, seed: 11);
      canvas.save();
      canvas.clipPath(remaining);
    }

    _ink(canvas, h);
    final soak = Curves.easeOutCubic.transform(((age - 0.75) / 0.9).clamp(0.0, 1.0));
    if (soak > 0) _page(canvas, memory, soak, h);

    if (remaining != null) {
      canvas.restore();
      _fire(canvas, remaining, burnP);
    }
  }

  /// The ink bleeding out, with splatter flung ahead of it and drips running down.
  void _ink(Canvas canvas, double h) {
    final grow = Curves.easeOutCubic.transform((age / _inkIn).clamp(0.0, 1.0));
    final ink = Paint()..color = const Color(0xFF120B08);
    if (grow >= 1) {
      canvas.drawRect(Rect.fromLTWH(0, 0, _w, h), ink);
      return;
    }
    final r = 14 + 900 * grow;
    canvas.drawPath(noisyBlob(_from, r, age), ink);
    for (var i = 0; i < 30; i++) {
      final a = hash01(i + 21) * math.pi * 2, d = 1.04 + hash01(i + 22) * 0.5;
      canvas.drawCircle(_from + Offset(math.cos(a), math.sin(a)) * r * d, (1.5 + hash01(i + 23) * 7) * (0.5 + grow), ink);
    }
    for (var i = 0; i < 9; i++) {
      final a = math.pi * (0.15 + 0.7 * hash01(i + 31));
      final p = _from + Offset(math.cos(a), math.sin(a)) * r * 0.95;
      final length = (30 + hash01(i + 32) * 70) * grow;
      canvas.drawRect(Rect.fromLTWH(p.dx - 2.5, p.dy, 5, length), ink);
      canvas.drawCircle(Offset(p.dx, p.dy + length), 4, ink);
    }
  }

  /// The page the ink soaks away to reveal, with everything on it.
  void _page(Canvas canvas, Memory memory, double soak, double h) {
    final page = this.page;
    final edge = tornRect(page, 11);
    canvas.save();
    canvas.clipPath(edge);
    if (soak < 1) canvas.clipPath(noisyBlob(Offset(_w / 2, h * 0.45), 560 * soak, age, rough: 0.3, seed: 9));
    canvas.drawPicture(_paperFor(page));

    // the caption, inked across the top
    final caption = ramp(age, 1.1, 1.6);
    const brown = Color(0xFF4A2014);
    final words = game.strings;
    PixelFont.draw(canvas, words.realmName(memory.realm), page.left + 16, page.top + 22, 1.6, brown.withValues(alpha: caption));
    final remembered = words.remembered;
    PixelFont.draw(canvas, remembered, page.right - 16 - PixelFont.widthOf(remembered, 1.6), page.top + 22, 1.6,
        brown.withValues(alpha: caption));
    canvas.drawLine(Offset(page.left + 16, page.top + 42), Offset(page.left + 16 + (page.width - 32) * caption, page.top + 42),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0x993A2618));

    // the scene, on its own torn sheet with a shadow under it
    final box = scene;
    final sheet = tornRect(box, 4, tooth: 8, depth: 4);
    canvas.save();
    canvas.translate(3, 5);
    canvas.drawPath(sheet, Paint()..color = const Color(0x59281808));
    canvas.restore();
    canvas.save();
    canvas.clipPath(sheet);
    drawMemoryScene(canvas, box, memory, age, game.sprites);
    canvas.restore();

    // the words, in the game's own letters; in deep memories some break into stray symbols
    final c = corruptionOf(memory);
    final lines = PixelFont.wrap(words.memory(memory), 25);
    var chars = typed ? 1 << 20 : ((age - _typeFrom) * _lettersPerSecond).floor();
    const px = 2.2;
    final frame = (age * 10).floor();
    for (var i = 0; i < lines.length && chars > 0; i++) {
      final line = lines[i];
      final shown = math.min(line.length, chars);
      chars -= line.length + 1;
      final left = _w / 2 - PixelFont.widthOf(line, px) / 2, y = box.bottom + 30 + i * 22;
      for (var k = 0; k < shown; k++) {
        var ch = line[k];
        var color = const Color(0xFF2A1A10);
        var at = Offset(left + k * 6 * px, y);
        if (c > 0 && ch != ' ' && hash01(k * 31 + frame * 7 + i) < 0.22 * c) {
          ch = '#?!&+-:0123456789'[(hash01(k + frame * 3) * 17).floor() % 17];
          color = Palette.blood;
          at += Offset((hash01(k + 1) - 0.5) * 4, (hash01(k + 2) - 0.5) * 4);
        }
        PixelFont.draw(canvas, ch, at.dx, at.dy, px, color);
      }
    }

    // a quill and the prompt, once the words are out
    if (typed && !burning) {
      final pulse = 0.75 + 0.25 * math.sin(age * 3.2);
      final label = words.toContinue(touch: game.state.touchUi);
      final lx = _w / 2 - PixelFont.widthOf(label, 1.6) / 2 + 10, ly = page.bottom - 40;
      PixelFont.draw(canvas, label, lx, ly, 1.6, brown.withValues(alpha: pulse));
      final quill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = brown.withValues(alpha: pulse);
      canvas.drawPath(
          Path()
            ..moveTo(lx - 22, ly + 12)
            ..quadraticBezierTo(lx - 18, ly - 2, lx - 8, ly - 6)
            ..moveTo(lx - 22, ly + 12)
            ..lineTo(lx - 24, ly + 15),
          quill);
    }
    canvas.restore();
    canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x80502A19));
  }

  /// The burning edge: a band of char, a glowing rim, and embers rising off it.
  void _fire(Canvas canvas, Path remaining, double p) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(remaining, stroke
      ..strokeWidth = 16
      ..color = const Color(0xB31E0E06));
    canvas.drawPath(remaining, stroke
      ..strokeWidth = 7
      ..color = const Color(0xCCD9682E));
    canvas.drawPath(remaining, stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFFC870));
    final ember = Paint();
    final h = game.state.height;
    for (var i = 0; i < 40; i++) {
      final a = math.max(0.0, math.sin(math.pi * (p * 1.4 - hash01(i + 44) * 0.4).clamp(0.0, 1.0)));
      if (a <= 0) continue;
      ember.color = Color.fromRGBO(255, 150 + (hash01(i + 45) * 80).round(), 60, a);
      final y = hash01(i + 42) * h - (age - _burnAt!) * (20 + hash01(i + 43) * 50) * 2;
      canvas.drawRect(Rect.fromLTWH(hash01(i + 41) * _w + math.sin(age * 3 + i) * 6, y, 2, 2), ember);
    }
  }

  /// Old paper: warm and uneven, with grain, a few faint stains and darker edges. Made once
  /// per page size.
  Picture _paperFor(Rect page) {
    if (_paper != null && _paperHeight == page.height) return _paper!;
    _paper?.dispose();
    final recorder = PictureRecorder();
    final g = Canvas(recorder);
    g.drawRect(
        page,
        Paint()
          ..shader = Gradient.linear(page.topCenter, page.bottomCenter, const [Color(0xFFE6D6B2), Color(0xFFD6C29A)]));
    for (var i = 0; i < 6; i++) {
      final at = Offset(page.left + hash01(i + 3) * page.width, page.top + hash01(i + 7) * page.height);
      final r = 30 + hash01(i + 9) * 70;
      g.drawCircle(
          at,
          r,
          Paint()
            ..shader = Gradient.radial(at, r, const [Color(0x12784F28), Color(0x0F6E4623), Color(0x006E4623)], [0, 0.8, 1]));
    }
    final grain = Paint();
    for (var i = 0; i < 700; i++) {
      grain.color = hash01(i + 500) < 0.5 ? const Color(0x18FFF6E0) : const Color(0x1A5A3A1E);
      g.drawRect(
          Rect.fromLTWH(page.left + hash01(i + 600) * page.width, page.top + hash01(i + 900) * page.height, 1.2, 1.2), grain);
    }
    g.drawRect(
        page,
        Paint()
          ..shader = Gradient.radial(page.center, page.height * 0.7,
              const [Color(0x003C230F), Color(0x733C230F)], [0.45, 1]));
    _paper = recorder.endRecording();
    _paperHeight = page.height;
    return _paper!;
  }

  @override
  void onRemove() {
    _paper?.dispose();
    _paper = null;
    super.onRemove();
  }
}
