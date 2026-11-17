import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import '../strings.dart';

/// Everything drawn over the world in field coordinates: the score panels, power-up timer,
/// hints and toasts, plus the title and game-over screens and their buttons. Lives in the
/// camera's viewport. Memories come back here too, as flashbacks over a frozen, sepia world. While the shop or the memories book
/// is open, only the speaker button shows.
class Hud extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  @override
  void render(Canvas canvas) {
    final state = game.state;
    if (!game.shop.isOpen && !game.book.isOpen) {
      switch (state.mode) {
        case GameMode.title:
          _title(canvas, state);
        case GameMode.playing:
          _panels(canvas, state);
        case GameMode.dead:
          _panels(canvas, state);
          _gameOver(canvas, state);
      }
    }
    if (game.showsMuteButton) _muteButton(canvas, game.muteButton, game.muted);
    if (game.showsShopButton) _shopButton(canvas, game.shopButton, state);
    if (game.showsMemoriesButton) _memoriesButton(canvas, game.memoriesButton, state);
    if (game.showsLanguageButton) _languageButton(canvas, game.languageButton);
    if (game.showsTripleShieldButton) _boostButton(canvas, game.tripleShieldButton, PowerUp.shield, state.tripleShields, 'X3');
    if (game.showsTurboButton) _turboButton(canvas, game.turboButton, state.turbos);
  }

  /// "EN | ES", the language in use lit up.
  void _languageButton(Canvas canvas, Rect rect) {
    drawPanel(canvas, rect);
    final es = game.lang == Lang.es;
    PixelFont.draw(canvas, 'EN', rect.left + 10, rect.top + 8, 2, es ? Palette.muted : Palette.sun);
    PixelFont.draw(canvas, '-', rect.left + 36, rect.top + 8, 2, Palette.muted);
    PixelFont.draw(canvas, 'ES', rect.left + 46, rect.top + 8, 2, es ? Palette.sun : Palette.muted);
  }

  /// The turbo button: a lightning bolt, and how many are left.
  void _turboButton(Canvas canvas, Rect rect, int count) {
    drawPanel(canvas, rect, edge: Palette.sun);
    drawBolt(canvas, rect.center, 30, Palette.sun);
    _count(canvas, rect, count);
  }

  /// A power-up's button: its badge, a label, and how many are left.
  void _boostButton(Canvas canvas, Rect rect, PowerUp badge, int count, String label) {
    drawPanel(canvas, rect, edge: Palette.shield);
    drawPowerUp(canvas, rect.center + const Offset(0, -4), badge, 13);
    PixelFont.drawCentered(canvas, label, rect.center.dx, rect.bottom - 13, 1.5, Palette.text);
    _count(canvas, rect, count);
  }

  void _count(Canvas canvas, Rect rect, int count) {
    final text = '$count';
    final w = PixelFont.widthOf(text, 1.5) + 8;
    final badge = Rect.fromLTWH(rect.right - w + 4, rect.top - 6, w, 15);
    canvas.drawRRect(RRect.fromRectAndRadius(badge, const Radius.circular(4)), Paint()..color = Palette.hot);
    PixelFont.drawCentered(canvas, text, badge.center.dx, badge.top + 2.5, 1.5, Palette.text);
  }

  /// "MEMORIES", glowing with a blinking dot when one has come back since the book was opened.
  void _memoriesButton(Canvas canvas, Rect rect, GameState state) {
    final news = state.newMemories;
    drawPanel(canvas, rect, edge: news ? Palette.glimmer : Palette.panelEdge);
    PixelFont.drawCentered(canvas, game.strings.memories, rect.center.dx, rect.top + 9, 2, news ? Palette.glimmer : Palette.text);
    if (news && blinkOn(state.time)) {
      canvas.drawCircle(rect.topRight + const Offset(-3, 3), 5, Paint()..color = Palette.glimmer);
    }
  }

  /// A coin and "SHOP". When something new is affordable, the edge turns gold and a dot blinks.
  void _shopButton(Canvas canvas, Rect rect, GameState state) {
    final news = game.canBuySomething;
    drawPanel(canvas, rect, edge: news ? Palette.sun : Palette.panelEdge);
    drawCoin(canvas, Offset(rect.left + 17, rect.center.dy), 7);
    PixelFont.draw(canvas, game.strings.shop, rect.left + 32, rect.top + 9, 2, news ? Palette.sun : Palette.text);
    if (news && blinkOn(state.time)) {
      canvas.drawCircle(rect.topRight + const Offset(-3, 3), 5, Paint()..color = Palette.hot);
    }
  }

  /// A speaker: sound waves when on, a cross when muted.
  void _muteButton(Canvas canvas, Rect rect, bool muted) {
    drawPanel(canvas, rect);
    final c = rect.center;
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - 9, c.dy - 3.5)
          ..lineTo(c.dx - 5, c.dy - 3.5)
          ..lineTo(c.dx + 1, c.dy - 8)
          ..lineTo(c.dx + 1, c.dy + 8)
          ..lineTo(c.dx - 5, c.dy + 3.5)
          ..lineTo(c.dx - 9, c.dy + 3.5)
          ..close(),
        Paint()..color = Palette.text);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = muted ? Palette.hot : Palette.text;
    if (muted) {
      canvas.drawLine(Offset(c.dx + 4, c.dy - 4), Offset(c.dx + 10, c.dy + 4), stroke);
      canvas.drawLine(Offset(c.dx + 10, c.dy - 4), Offset(c.dx + 4, c.dy + 4), stroke);
    } else {
      for (final r in const [5.0, 9.0]) {
        canvas.drawArc(Rect.fromCircle(center: Offset(c.dx + 1, c.dy), radius: r), -0.9, 1.8, false, stroke);
      }
    }
  }

  void _panels(Canvas canvas, GameState state) {
    final top = 10 + game.safeTop;

    final words = game.strings;
    final number = '${state.screens}';
    final labelW = PixelFont.widthOf(words.screens, 2), numberW = PixelFont.widthOf(number, 6);
    final boxW = math.max(labelW, numberW) + 20;
    final boxX = _w - 10 - boxW;
    drawPanel(canvas, Rect.fromLTWH(boxX, top, boxW, 78));
    PixelFont.draw(canvas, words.screens, boxX + boxW - 10 - labelW, top + 10, 2, Palette.muted);
    PixelFont.draw(canvas, number, boxX + boxW - 10 - numberW, top + 28, 6,
        state.popTime > 0 ? Palette.sun : Palette.text,
        shadow: Palette.hot);

    // left column: best run, then the coin total
    var leftY = top;
    if (state.best > 0) {
      final label = '${words.best} ';
      final value = '${state.best}';
      drawPanel(canvas, Rect.fromLTWH(10, leftY, PixelFont.widthOf(label + value, 2) + 16, 26));
      PixelFont.draw(canvas, label, 18, leftY + 6, 2, Palette.muted);
      PixelFont.draw(canvas, value, 18 + label.length * 12, leftY + 6, 2, Palette.sun);
      leftY += 32;
    }
    final coinText = '${state.coins}';
    drawPanel(canvas, Rect.fromLTWH(10, leftY, 36 + PixelFont.widthOf(coinText, 2), 26));
    drawCoin(canvas, Offset(24, leftY + 13), 7);
    PixelFont.draw(canvas, coinText, 37, leftY + 6, 2, state.coinPopTime > 0 ? Palette.sun : Palette.text);

    // right column, under the screen count: the shield, with a pip for each hit it can take
    if (state.shield) {
      final rect = Rect.fromLTWH(_w - 40, top + 86, 30, 30);
      drawPanel(canvas, rect);
      drawPowerUp(canvas, rect.center, PowerUp.shield, 10);
      if (state.shieldHits > 1) {
        for (var i = 0; i < state.shieldHits; i++) {
          canvas.drawCircle(Offset(rect.left - 8 - i * 10, rect.center.dy), 3.5, Paint()..color = Palette.shield);
        }
      }
    }

    if (state.mode == GameMode.playing && !state.holding && blinkOn(state.time)) {
      final hint = words.holdToSteer;
      final w = PixelFont.widthOf(hint, 2) + 20;
      final y = state.height - 50 - game.safeBottom;
      drawPanel(canvas, Rect.fromLTWH((_w - w) / 2, y, w, 28));
      PixelFont.drawCentered(canvas, hint, _w / 2, y + 7, 2, Palette.sun);
    }

    if (state.mode == GameMode.playing && state.realmCardTime > 0) _realmCard(canvas, state);

    if (state.toastTime > 0) {
      // long messages shrink to fit the field
      final toast = words.toast(state.toast, state.toastValue);
      final px = math.min(4.0, (_w - 24) / (toast.length * 6 - 1));
      PixelFont.drawCentered(canvas, toast, _w / 2, state.height * 0.27 - (1.6 - state.toastTime) * 20, px,
          Palette.sun,
          shadow: Palette.ink);
    }
  }

  /// "ENTERING" and the realm's name, fading in and out between two little diamonds.
  void _realmCard(Canvas canvas, GameState state) {
    final shown = GameState.realmCardSeconds - state.realmCardTime;
    final alpha = math.min(1.0, math.min(shown / 0.5, state.realmCardTime / 0.8));
    final name = game.strings.realmName(state.realm);
    final y = state.height * 0.36 - shown * 6; // drifts gently upward
    PixelFont.drawCentered(canvas, game.strings.entering, _w / 2, y, 2, Palette.muted.withValues(alpha: alpha));
    _glitchText(canvas, name, y + 22, 4, Palette.glimmer.withValues(alpha: alpha), Palette.ink.withValues(alpha: alpha),
        state.time, ramp(game.corruption, 0.3, 1));
    final half = PixelFont.widthOf(name, 4) / 2 + 18;
    final diamond = Paint()..color = Palette.runeViolet.withValues(alpha: alpha);
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(_w / 2 + side * half, y + 36);
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 6)
            ..lineTo(c.dx + 5, c.dy)
            ..lineTo(c.dx, c.dy + 6)
            ..lineTo(c.dx - 5, c.dy)
            ..close(),
          diamond);
    }
  }

  /// [text] centred at [y], each letter now and then jumping aside in a hot colour, more often
  /// the more [corruption] there is.
  void _glitchText(Canvas canvas, String text, double y, double px, Color color, Color shadow, double time,
      double corruption) {
    final left = _w / 2 - PixelFont.widthOf(text, px) / 2;
    final frame = (time * 14).floor();
    for (var i = 0; i < text.length; i++) {
      final x = left + i * 6 * px;
      final glitch = corruption > 0 && hash01(i * 7 + frame * 31) < 0.22 * corruption;
      if (glitch) {
        final dx = (hash01(i + frame * 13) - 0.5) * 10, dy = (hash01(i * 3 + frame) - 0.5) * 8;
        PixelFont.draw(canvas, text[i], x + dx, y + dy, px, Palette.hot.withValues(alpha: color.a));
      } else {
        PixelFont.draw(canvas, text[i], x, y, px, color, shadow: shadow);
      }
    }
  }

  void _title(Canvas canvas, GameState state) {
    final top = math.max(64.0, state.height * 0.09) + game.safeTop;

    // "going" in rainbow letters over a big "UP"
    const going = 'going';
    var x = (_w - PixelFont.widthOf(going, 6)) / 2;
    for (var i = 0; i < going.length; i++, x += 36) {
      final dy = math.sin(state.time * 4.5 - i * 0.6) * 4;
      PixelFont.draw(canvas, going[i], x, top + dy, 6, Palette.logo[i % Palette.logo.length], shadow: Palette.ink);
    }
    const up = 'UP';
    x = (_w - PixelFont.widthOf(up, 12)) / 2;
    for (var i = 0; i < up.length; i++, x += 72) {
      final dy = math.sin(state.time * 4.5 - (i + 5) * 0.6) * 4;
      PixelFont.draw(canvas, up[i], x + 4, top + 58 + dy + 4, 12, Palette.hot);
      PixelFont.draw(canvas, up[i], x, top + 58 + dy, 12, Palette.text);
    }

    final words = game.strings;
    final lines = words.howToPlay(touch: state.touchUi);
    final panelY = math.max(top + 170, state.height * 0.37);
    drawPanel(canvas, Rect.fromLTWH(36, panelY, _w - 72, 124));
    var ly = panelY + 14;
    for (final line in lines) {
      PixelFont.drawCentered(canvas, line, _w / 2, ly, 2, Palette.muted);
      ly += 20;
    }
    PixelFont.drawCentered(canvas, words.dontTouchTheWalls, _w / 2, ly, 2, Palette.sun);

    final bottom = state.height - game.safeBottom;
    if (blinkOn(state.time)) _callToAction(canvas, words.start(touch: state.touchUi), bottom - 120);
    // best run and coins on one line, between the call to action and the buttons
    final best = state.best > 0 ? '${words.best} ${state.best}' : '';
    final coins = state.coins > 0 ? '${state.coins}' : '';
    if (best.isNotEmpty || coins.isNotEmpty) {
      final gap = best.isNotEmpty && coins.isNotEmpty ? 24.0 : 0.0;
      final coinW = coins.isEmpty ? 0.0 : 20 + PixelFont.widthOf(coins, 2);
      var x = _w / 2 - (PixelFont.widthOf(best, 2) + gap + coinW) / 2;
      final y = bottom - 66;
      PixelFont.draw(canvas, best, x, y, 2, Palette.muted, shadow: Palette.ink);
      x += PixelFont.widthOf(best, 2) + gap;
      if (coins.isNotEmpty) {
        drawCoin(canvas, Offset(x + 7, y + 7), 7);
        PixelFont.draw(canvas, coins, x + 20, y, 2, Palette.muted, shadow: Palette.ink);
      }
    }
  }

  void _gameOver(Canvas canvas, GameState state) {
    if (!state.showGameOver) return;
    final top = math.max(70.0, state.height * 0.12) + game.safeTop;
    final words = game.strings;
    final title = state.spooked ? words.gotYou : words.bonk;
    PixelFont.drawCentered(canvas, title, _w / 2, top, _fit(title, 10, _w - 24), Palette.hot, shadow: Palette.ink);
    if (state.realm > 0) {
      _glitchText(canvas, words.inRealm(state.realm), top + 84, 2, Palette.glimmer, Palette.ink, state.time,
          ramp(game.corruption, 0.3, 1) * 0.5);
    }

    final panelY = top + 110;
    drawPanel(canvas, Rect.fromLTWH(52, panelY, _w - 104, 236));
    PixelFont.drawCentered(canvas, words.youFlewPast, _w / 2, panelY + 20, 2, Palette.muted);
    PixelFont.drawCentered(canvas, '${state.screens}', _w / 2, panelY + 46, 10, Palette.text, shadow: Palette.hot);
    PixelFont.drawCentered(canvas, words.screens, _w / 2, panelY + 132, 2, Palette.muted);
    _coinLine(canvas, '+${words.coins(state.runCoins)}', panelY + 160, Palette.sun);
    if (state.newBest && state.screens > 0) {
      final text = words.newBest;
      if (blinkOn(state.time)) PixelFont.drawCentered(canvas, text, _w / 2, panelY + 190, _fit(text, 4, _w - 120), Palette.sun);
    } else {
      PixelFont.drawCentered(canvas, '${words.best} ${state.best}', _w / 2, panelY + 198, 2, Palette.muted);
    }

    if (state.canRetry && blinkOn(state.time)) {
      _callToAction(canvas, words.retry, state.height - game.safeBottom - 120);
    }
  }

  void _callToAction(Canvas canvas, String text, double y) {
    final px = _fit(text, 4, _w - 60);
    final w = PixelFont.widthOf(text, px) + 28;
    drawPanel(canvas, Rect.fromLTWH((_w - w) / 2, y, w, 48), edge: Palette.sun);
    PixelFont.drawCentered(canvas, text, _w / 2, y + 24 - 3.5 * px, px, Palette.sun);
  }

  /// The pixel size for [text]: [most], or smaller if it would be wider than [room].
  static double _fit(String text, double most, double room) => math.min(most, room / (text.length * 6 - 1));

  /// A coin icon followed by [text], centred as one line.
  void _coinLine(Canvas canvas, String text, double y, Color color) {
    final w = 22 + PixelFont.widthOf(text, 2);
    final x = (_w - w) / 2;
    drawCoin(canvas, Offset(x + 7, y + 7), 7);
    PixelFont.draw(canvas, text, x + 22, y, 2, color, shadow: Palette.ink);
  }

}
