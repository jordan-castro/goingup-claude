import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';

/// Everything drawn over the world in field coordinates: the score panels, power-up timer,
/// hints and toasts, plus the title and game-over screens. Lives in the camera's viewport.
class Hud extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  @override
  void render(Canvas canvas) {
    final state = game.state;
    switch (state.mode) {
      case GameMode.title:
        _title(canvas, state);
      case GameMode.playing:
        _panels(canvas, state);
      case GameMode.dead:
        _panels(canvas, state);
        _gameOver(canvas, state);
    }
    if (game.showsMuteButton) _muteButton(canvas, game.muteButton, game.music.muted);
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

    final number = '${state.screens}';
    final labelW = PixelFont.widthOf('SCREENS', 2), numberW = PixelFont.widthOf(number, 6);
    final boxW = math.max(labelW, numberW) + 20;
    final boxX = _w - 10 - boxW;
    drawPanel(canvas, Rect.fromLTWH(boxX, top, boxW, 78));
    PixelFont.draw(canvas, 'SCREENS', boxX + boxW - 10 - labelW, top + 10, 2, Palette.muted);
    PixelFont.draw(canvas, number, boxX + boxW - 10 - numberW, top + 28, 6,
        state.popTime > 0 ? Palette.sun : Palette.text,
        shadow: Palette.hot);

    // left column: best run, then the coin total
    var leftY = top;
    if (state.best > 0) {
      const label = 'BEST ';
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

    // right column, under the screen count: the timed power-up and the shield
    var rightY = top + 86;
    final effect = state.effect;
    if (effect != null) {
      final rect = Rect.fromLTWH(_w - 134, rightY, 124, 30);
      drawPanel(canvas, rect);
      drawPowerUp(canvas, Offset(rect.left + 16, rect.center.dy), effect, 10);
      final bar = Rect.fromLTWH(rect.left + 32, rect.center.dy - 4, 82, 8);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(4)), Paint()..color = Palette.ink);
      final left = (state.effectTime / state.effectDuration).clamp(0.0, 1.0);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, bar.width * left, bar.height), const Radius.circular(4)),
          Paint()..color = Palette.powerUp(effect));
      rightY += 36;
    }
    if (state.shield) {
      final rect = Rect.fromLTWH(_w - 40, rightY, 30, 30);
      drawPanel(canvas, rect);
      drawPowerUp(canvas, rect.center, PowerUp.shield, 10);
    }

    if (state.mode == GameMode.playing && !state.holding && blinkOn(state.time)) {
      const hint = 'HOLD TO STEER';
      final w = PixelFont.widthOf(hint, 2) + 20;
      final y = state.height - 50 - game.safeBottom;
      drawPanel(canvas, Rect.fromLTWH((_w - w) / 2, y, w, 28));
      PixelFont.drawCentered(canvas, hint, _w / 2, y + 7, 2, Palette.sun);
    }

    if (state.toastTime > 0) {
      // long messages shrink to fit the field
      final px = math.min(4.0, (_w - 24) / (state.toast.length * 6 - 1));
      PixelFont.drawCentered(canvas, state.toast, _w / 2, state.height * 0.27 - (1.6 - state.toastTime) * 20, px,
          Palette.sun,
          shadow: Palette.ink);
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

    final lines = state.touchUi
        ? const ['TOUCH AND HOLD THE', 'SCREEN TO FLY.', 'THE BUNNY FOLLOWS YOUR', 'FINGER WHILE YOU HOLD.']
        : const ['PRESS AND HOLD THE LEFT', 'MOUSE BUTTON TO FLY.', 'THE BUNNY FOLLOWS YOUR', 'CURSOR WHILE YOU HOLD.'];
    final panelY = math.max(top + 170, state.height * 0.37);
    drawPanel(canvas, Rect.fromLTWH(36, panelY, _w - 72, 124));
    var ly = panelY + 14;
    for (final line in lines) {
      PixelFont.drawCentered(canvas, line, _w / 2, ly, 2, Palette.muted);
      ly += 20;
    }
    PixelFont.drawCentered(canvas, "DON'T TOUCH THE WALLS!", _w / 2, ly, 2, Palette.sun);

    final bottom = state.height - game.safeBottom;
    if (blinkOn(state.time)) _callToAction(canvas, state.touchUi ? 'TOUCH & HOLD' : 'PRESS & HOLD', bottom - 120);
    if (state.best > 0) {
      PixelFont.drawCentered(canvas, 'BEST ${state.best} SCREENS', _w / 2, bottom - 54, 2, Palette.muted,
          shadow: Palette.ink);
    }
    if (state.coins > 0) _coinLine(canvas, _coinCount(state.coins), bottom - 30, Palette.muted);
  }

  void _gameOver(Canvas canvas, GameState state) {
    if (!state.showGameOver) return;
    final top = math.max(70.0, state.height * 0.12) + game.safeTop;
    PixelFont.drawCentered(canvas, 'BONK!', _w / 2, top, 10, Palette.hot, shadow: Palette.ink);

    final panelY = top + 110;
    drawPanel(canvas, Rect.fromLTWH(52, panelY, _w - 104, 236));
    PixelFont.drawCentered(canvas, 'YOU FLEW PAST', _w / 2, panelY + 20, 2, Palette.muted);
    PixelFont.drawCentered(canvas, '${state.screens}', _w / 2, panelY + 46, 10, Palette.text, shadow: Palette.hot);
    PixelFont.drawCentered(canvas, 'SCREENS', _w / 2, panelY + 132, 2, Palette.muted);
    _coinLine(canvas, '+${_coinCount(state.runCoins)}', panelY + 160, Palette.sun);
    if (state.newBest && state.screens > 0) {
      if (blinkOn(state.time)) PixelFont.drawCentered(canvas, 'NEW BEST!', _w / 2, panelY + 190, 4, Palette.sun);
    } else {
      PixelFont.drawCentered(canvas, 'BEST ${state.best}', _w / 2, panelY + 198, 2, Palette.muted);
    }

    if (state.canRetry && blinkOn(state.time)) {
      _callToAction(canvas, 'HOLD TO RETRY', state.height - game.safeBottom - 120);
    }
  }

  void _callToAction(Canvas canvas, String text, double y) {
    final w = PixelFont.widthOf(text, 4) + 28;
    drawPanel(canvas, Rect.fromLTWH((_w - w) / 2, y, w, 48), edge: Palette.sun);
    PixelFont.drawCentered(canvas, text, _w / 2, y + 10, 4, Palette.sun);
  }

  /// A coin icon followed by [text], centred as one line.
  void _coinLine(Canvas canvas, String text, double y, Color color) {
    final w = 22 + PixelFont.widthOf(text, 2);
    final x = (_w - w) / 2;
    drawCoin(canvas, Offset(x + 7, y + 7), 7);
    PixelFont.draw(canvas, text, x + 22, y, 2, color, shadow: Palette.ink);
  }

  static String _coinCount(int n) => '$n ${n == 1 ? 'COIN' : 'COINS'}';
}
