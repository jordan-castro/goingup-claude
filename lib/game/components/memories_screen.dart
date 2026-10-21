import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';

/// The memories book, opened from the title and game-over screens: one page per realm, with
/// the memories Pip has got back written on scraps of paper and the forgotten ones left as
/// shadows. Field coordinates, drawn over everything but the speaker button.
class MemoriesScreen extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  bool isOpen = false;

  /// The realm whose page is showing.
  int page = 0;

  void open() {
    isOpen = true;
    final state = game.state;
    // start at the deepest page with something found on it
    page = 0;
    for (final m in Memories.all) {
      if (state.memories.contains(m.id)) page = math.max(page, m.realm);
    }
    state.newMemories = false;
  }

  void close() => isOpen = false;

  void turn(int by) {
    final next = (page + by).clamp(0, GameState.realms.length - 1);
    if (next == page) return;
    page = next;
    game.sfx.play(const SoundCue(Sfx.click));
  }

  // ---------- layout (field units) ----------

  /// Top of the book, which is 618 tall: centred when the screen has room to spare.
  double get _top {
    final top = 10 + game.safeTop;
    final spare = (game.state.height - game.safeBottom - 12) - (top + 618);
    return top + math.max(0.0, spare / 2);
  }

  Rect get previousButton => Rect.fromLTWH(16, _top + 50, 44, 36);
  Rect get nextButton => Rect.fromLTWH(_w - 60, _top + 50, 44, 36);
  Rect get backButton => Rect.fromLTWH((_w - 140) / 2, _top + 578, 140, 40);

  /// Where each memory of the page goes, top to bottom.
  List<Rect> get entries {
    final state = game.state;
    final rects = <Rect>[];
    var y = _top + 100;
    for (final m in Memories.ofRealm(page)) {
      final found = state.memories.contains(m.id);
      final h = found ? 28.0 + PixelFont.wrap(m.text, 26).length * 19 : 36.0;
      rects.add(Rect.fromLTWH(24, y, _w - 48, h));
      y += h + 10;
    }
    return rects;
  }

  // ---------- input ----------

  void press(Offset p) {
    bool hit(Rect r) => r.inflate(4).contains(p);
    if (hit(previousButton)) {
      turn(-1);
    } else if (hit(nextButton)) {
      turn(1);
    } else if (hit(backButton)) {
      close();
      game.sfx.play(const SoundCue(Sfx.click));
    }
  }

  // ---------- drawing ----------

  @override
  void render(Canvas canvas) {
    if (!isOpen) return;
    final state = game.state;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, state.height), Paint()..color = Palette.page.withValues(alpha: 0.93));
    final top = _top;

    PixelFont.draw(canvas, 'MEMORIES', 16, top + 6, 4, Palette.text, shadow: Palette.inkRed);
    final count = '${state.memories.length} OF ${Memories.all.length}';
    final countW = PixelFont.widthOf(count, 2) + 20;
    drawPanel(canvas, Rect.fromLTWH(_w - 16 - countW, top + 6, countW, 26));
    PixelFont.draw(canvas, count, _w - 6 - countW, top + 12, 2, Palette.glimmer);

    // the realm, between page arrows
    final memories = Memories.ofRealm(page);
    final reached = state.memories.contains(Memories.arrivalOf(page).id);
    final name = reached ? GameState.realms[page].name : '? ? ?';
    PixelFont.drawCentered(canvas, name, _w / 2, top + 58, 3, reached ? Palette.glimmer : Palette.muted, shadow: Palette.ink);
    _arrow(canvas, previousButton, -1, enabled: page > 0);
    _arrow(canvas, nextButton, 1, enabled: page < GameState.realms.length - 1);

    final rects = entries;
    for (var i = 0; i < memories.length; i++) {
      final m = memories[i], rect = rects[i];
      if (state.memories.contains(m.id)) {
        drawPaper(canvas, rect, Memories.all.indexOf(m) * 37 + 5);
        final lines = PixelFont.wrap(m.text, 26);
        for (var j = 0; j < lines.length; j++) {
          PixelFont.drawCentered(canvas, lines[j], rect.center.dx, rect.top + 14 + j * 19, 2, Palette.ink);
        }
      } else {
        // a forgotten memory: only its shadow
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..color = Palette.shade.withValues(alpha: 0.5));
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Palette.muted.withValues(alpha: 0.3));
        PixelFont.drawCentered(canvas, m.arrival ? 'REACH THIS REALM TO REMEMBER' : '- FORGOTTEN -', rect.center.dx,
            rect.top + 12, m.arrival ? 1.5 : 2, Palette.muted.withValues(alpha: 0.6));
      }
    }

    final back = backButton;
    drawPanel(canvas, back);
    PixelFont.drawCentered(canvas, 'BACK', back.center.dx, back.top + 11, 3, Palette.text);
  }

  void _arrow(Canvas canvas, Rect rect, double dir, {required bool enabled}) {
    drawPanel(canvas, rect, edge: enabled ? Palette.panelEdge : Palette.muted.withValues(alpha: 0.3));
    final c = rect.center;
    canvas.drawPath(
        Path()
          ..moveTo(c.dx + dir * 7, c.dy)
          ..lineTo(c.dx - dir * 5, c.dy - 8)
          ..lineTo(c.dx - dir * 5, c.dy + 8)
          ..close(),
        Paint()..color = enabled ? Palette.text : Palette.muted.withValues(alpha: 0.3));
  }
}
