import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import '../drawing.dart';
import 'memory_scenes.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import '../versus/match.dart';

/// Everything drawn over the world in field coordinates: the score panels, power-up timer,
/// hints and toasts, plus the title and game-over screens and their buttons. Lives in the
/// camera's viewport. Memories come back here too, as flashbacks over a frozen, sepia world.
/// In a race with a friend: the countdown, the friend's meters (and an arrow when they're off
/// the screen), and who won. While the shop, the memories book or the two-player screens are
/// open, only the speaker button shows.
class Hud extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  @override
  void render(Canvas canvas) {
    final state = game.state;
    if (!game.shop.isOpen && !game.book.isOpen && !game.versusScreen.isOpen) {
      switch (state.mode) {
        case GameMode.title:
          state.versus ? _countdown(canvas, state) : _title(canvas, state);
        case GameMode.playing:
          _panels(canvas, state);
        case GameMode.dead:
          _panels(canvas, state);
          state.versus ? _versusOver(canvas, state) : _gameOver(canvas, state);
      }
      _memory(canvas, state); // over everything else
    }
    if (game.showsMuteButton) _muteButton(canvas, game.muteButton, game.muted);
    if (game.showsShopButton) _shopButton(canvas, game.shopButton, state);
    if (game.showsMemoriesButton) _memoriesButton(canvas, game.memoriesButton, state);
    if (game.showsVersusButton) _versusButton(canvas, game.versusButton);
  }

  /// "2 PLAYERS", for racing a friend.
  void _versusButton(Canvas canvas, Rect rect) {
    drawPanel(canvas, rect, edge: Palette.glimmer);
    PixelFont.drawCentered(canvas, '2 PLAYERS', rect.center.dx, rect.top + 9, 2, Palette.glimmer);
  }

  /// Before a race: 3, 2, 1, each number popping in and shrinking, and the score so far.
  void _countdown(Canvas canvas, GameState state) {
    final match = game.match;
    if (match == null || match.phase != MatchPhase.countdown) return;
    final top = math.max(90.0, state.height * 0.16) + game.safeTop;
    PixelFont.drawCentered(canvas, 'GET READY!', _w / 2, top, 4, Palette.sun, shadow: Palette.ink);
    if (match.wins + match.losses > 0) {
      PixelFont.drawCentered(canvas, 'WINS ${match.wins} - ${match.losses}', _w / 2, top + 44, 2, Palette.muted);
    }
    final left = match.countdown.clamp(0.0, VersusMatch.countdownSeconds);
    final n = math.max(1, left.ceil());
    final px = 14 + 10 * Curves.easeIn.transform(left - left.floor());
    PixelFont.drawCentered(canvas, '$n', _w / 2, state.height * 0.42 - 3.5 * px, px, Palette.text, shadow: Palette.hot);
    PixelFont.drawCentered(canvas, 'THE LAST ONE FLYING WINS', _w / 2, state.height * 0.62, 2, Palette.muted,
        shadow: Palette.ink);
  }

  /// The friend's meters under the coins, "GO!" as the race starts, and an arrow at the edge
  /// of the screen when the friend is out of sight.
  void _friendPanel(Canvas canvas, GameState state, VersusMatch match, double y, double top) {
    final value = '${match.friendMeters}M';
    drawPanel(canvas, Rect.fromLTWH(10, y, PixelFont.widthOf('FRIEND $value', 2) + 16, 26), edge: Palette.glimmer);
    PixelFont.draw(canvas, 'FRIEND ', 18, y + 6, 2, Palette.muted);
    PixelFont.draw(canvas, value, 18 + 7 * 12, y + 6, 2, Palette.glimmer);
    if (state.mode != GameMode.playing) return;

    if (match.clock < 0.9) {
      final fade = 1 - ramp(match.clock, 0.5, 0.9);
      PixelFont.drawCentered(canvas, 'GO!', _w / 2, state.height * 0.36, 12, Palette.sun.withValues(alpha: fade),
          shadow: Palette.hot.withValues(alpha: fade));
    }

    if (!match.ghostVisible) return;
    final gy = state.screenY(match.ghostWy);
    final above = gy < 0;
    if (!above && gy <= state.height) return;
    final meters = ((match.ghostWy - state.worldY(state.bunnyY)) / GameState.unitsPerMeter).round();
    final x = match.ghostX.clamp(40.0, _w - 40);
    final at = above ? top + 128 : state.height - game.safeBottom - 30;
    final dir = above ? -1.0 : 1.0;
    canvas.drawPath(
        Path()
          ..moveTo(x, at + dir * 10)
          ..lineTo(x - 9, at)
          ..lineTo(x + 9, at)
          ..close(),
        Paint()..color = Palette.glimmer.withValues(alpha: 0.85));
    PixelFont.drawCentered(canvas, meters > 0 ? '+${meters}M' : '${meters}M', x, above ? at + 6 : at - 20, 2,
        Palette.glimmer, shadow: Palette.ink);
  }

  /// After a race: who won, both players' meters, the score, and REMATCH or LEAVE.
  void _versusOver(Canvas canvas, GameState state) {
    final match = game.match;
    if (match == null || !state.showGameOver) return;
    final top = math.max(120.0, state.height * 0.12 + 30) + game.safeTop; // below the three panels
    final result = match.result;
    final (title, color) = switch (result) {
      MatchResult.won => ('YOU WIN!', Palette.sun),
      MatchResult.lost => ('YOU LOSE', Palette.hot),
      MatchResult.draw => ('DRAW!', Palette.glimmer),
      null => (state.spooked ? 'GOT YOU.' : 'BONK!', Palette.hot),
    };
    PixelFont.drawCentered(canvas, title, _w / 2, top, 6, color, shadow: Palette.ink);
    final dots = '.' * ((state.time * 2).floor() % 4);
    final why = match.friendLeft
        ? 'YOUR FRIEND LEFT'
        : result == null
            ? 'WAITING FOR YOUR FRIEND$dots'
            : state.endedByMatch
                ? 'YOUR FRIEND CRASHED'
                : result == MatchResult.draw
                    ? 'YOU BOTH CRASHED AT ONCE'
                    : 'YOUR FRIEND KEPT FLYING';
    PixelFont.drawCentered(canvas, why, _w / 2, top + 56, 2, Palette.muted, shadow: Palette.ink);

    final panelY = top + 84;
    drawPanel(canvas, Rect.fromLTWH(40, panelY, _w - 80, 150));
    for (final (x, label, meters, tint) in [
      (_w * 0.3, 'YOU', state.meters, Palette.text),
      (_w * 0.7, 'FRIEND', match.friendMeters, Palette.glimmer),
    ]) {
      PixelFont.drawCentered(canvas, label, x, panelY + 16, 2, Palette.muted);
      PixelFont.drawCentered(canvas, '$meters', x, panelY + 40, 6, tint, shadow: Palette.hot);
      PixelFont.drawCentered(canvas, 'METERS', x, panelY + 92, 2, Palette.muted);
    }
    PixelFont.drawCentered(canvas, 'WINS ${match.wins} - ${match.losses}', _w / 2, panelY + 122, 2, Palette.sun);
    _coinLine(canvas, '+${_coinCount(state.runCoins)}', panelY + 166, Palette.sun);

    if (!game.showsMatchButtons) return;
    final rematch = game.rematchButton;
    if (game.showsRematchButton) {
      drawPanel(canvas, rematch, edge: Palette.sun);
      PixelFont.drawCentered(canvas, 'REMATCH', rematch.center.dx, rematch.top + 10, 4, Palette.sun);
      if (match.friendReady && blinkOn(state.time)) {
        PixelFont.drawCentered(canvas, 'YOUR FRIEND WANTS A REMATCH!', _w / 2, rematch.top - 24, 2, Palette.glimmer,
            shadow: Palette.ink);
      }
    } else if (match.ready) {
      PixelFont.drawCentered(canvas, 'WAITING FOR YOUR FRIEND...', _w / 2, rematch.center.dy - 7, 2, Palette.muted,
          shadow: Palette.ink);
    }
    final leave = game.leaveButton;
    drawPanel(canvas, leave);
    PixelFont.drawCentered(canvas, 'LEAVE', leave.center.dx, leave.top + 10, 3, Palette.text);
  }

  /// "MEMORIES", glowing with a blinking dot when one has come back since the book was opened.
  void _memoriesButton(Canvas canvas, Rect rect, GameState state) {
    final news = state.newMemories;
    drawPanel(canvas, rect, edge: news ? Palette.glimmer : Palette.panelEdge);
    PixelFont.drawCentered(canvas, 'MEMORIES', rect.center.dx, rect.top + 9, 2, news ? Palette.glimmer : Palette.text);
    if (news && blinkOn(state.time)) {
      canvas.drawCircle(rect.topRight + const Offset(-3, 3), 5, Paint()..color = Palette.glimmer);
    }
  }

  /// A memory coming back, like a flashback. The world freezes and washes to sepia while a
  /// blot of ink bursts out of the bunny and spreads across the screen. The picture swings in
  /// on its frame and develops like an old photograph, the strip of paper slides up, and the
  /// words type themselves out. Then a prompt to continue; on continuing, the ink draws back
  /// into the bunny and everything fades with it.
  void _memory(Canvas canvas, GameState state) {
    final memory = state.shownMemory;
    if (memory == null || state.mode != GameMode.playing) return;
    final age = state.memoryAge;
    final outro = state.memoryOutro < 0 ? 0.0 : (state.memoryOutro / GameState.memoryOutroSeconds).clamp(0.0, 1.0);
    final fade = state.readingMemory
        ? math.min(1.0, age / 0.4) * (1 - outro)
        : math.min(1.0, math.min(age / 0.4, (GameState.memorySeconds - age) / 0.6)).clamp(0.0, 1.0);
    final field = Rect.fromLTWH(0, 0, _w, state.height);
    canvas.drawRect(
        field,
        Paint()
          ..color = Palette.sepia.withValues(alpha: 0.9 * fade)
          ..blendMode = BlendMode.color);

    // the ink blot, spreading out of the bunny (and drawing back into it at the end)
    final from = Offset(state.bunnyX, state.bunnyY);
    final reach = math.sqrt(_w * _w + state.height * state.height);
    final grow = Curves.easeOutCubic.transform(ramp(age, 0, 0.75)) * (1 - Curves.easeInCubic.transform(outro));
    if (grow > 0) {
      final radius = 10 + reach * grow;
      final blot = Path();
      const points = 56;
      for (var i = 0; i <= points; i++) {
        final a = i / points * 2 * math.pi;
        final edge = 1 + 0.07 * math.sin(a * 5 + age * 3) + 0.05 * math.sin(a * 11 - age * 4) + 0.04 * math.sin(a * 17);
        final q = from + Offset(math.cos(a), math.sin(a)) * radius * edge;
        i == 0 ? blot.moveTo(q.dx, q.dy) : blot.lineTo(q.dx, q.dy);
      }
      blot.close();
      canvas.drawPath(blot, Paint()..color = const Color(0xFF1A110C).withValues(alpha: 0.82));
      // drips running down from the blot's edge while it spreads
      final drip = Paint()..color = const Color(0xFF1A110C).withValues(alpha: 0.82);
      for (var i = 0; i < 7; i++) {
        final a = math.pi * (0.15 + 0.7 * hash01(i + 300));
        final p = from + Offset(math.cos(a), math.sin(a)) * radius * 0.96;
        final length = 20 + 60 * hash01(i + 310) * grow;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 2.5, p.dy, 5, length), const Radius.circular(3)), drip);
        canvas.drawCircle(Offset(p.dx, p.dy + length), 4, drip);
      }
    }
    canvas.drawRect(
        field,
        Paint()
          ..shader = ui.Gradient.radial(Offset(_w / 2, state.height / 2), state.height * 0.62, [
            Palette.ink.withValues(alpha: 0),
            Palette.ink.withValues(alpha: 0.75 * fade),
          ], [
            0.5,
            1
          ]));

    // the picture, the words and the prompt, centred as one block
    final lines = PixelFont.wrap(memory.text, 26);
    final paperH = 22.0 + lines.length * 19;
    const pictureH = 170.0;
    final blockH = 30 + pictureH + 12 + paperH + 34;
    final top = math.max(game.safeTop + 12, (state.height - blockH) / 2);

    final heading = memory.arrival ? GameState.realms[memory.realm].name : 'A MEMORY';
    final headingIn = ramp(age, 0.5, 0.9) * (1 - outro);
    PixelFont.drawCentered(canvas, heading, _w / 2, top + 6 * (1 - headingIn), 3,
        Palette.parchment.withValues(alpha: headingIn), shadow: Palette.ink.withValues(alpha: headingIn));

    // the frame swings in and settles, overshooting a little
    final picture = Rect.fromLTWH(40, top + 30, _w - 80, pictureH);
    final drop = Curves.easeOutBack.transform(ramp(age, 0.25, 0.85)) * (1 - outro);
    if (drop > 0.001) {
      canvas.save();
      canvas.translate(picture.center.dx, picture.center.dy);
      canvas.rotate((1 - drop) * -0.18);
      canvas.scale(0.6 + 0.4 * drop);
      canvas.translate(-picture.center.dx, -picture.center.dy);
      canvas.saveLayer(picture.inflate(6), Paint()..color = Color.fromRGBO(0, 0, 0, math.min(1.0, drop) * fade));
      drawMemoryScene(canvas, picture, memory.scene, age);
      canvas.restore();
      canvas.restore();
    }

    // the strip of paper slides up into place, then the words type out
    final slide = Curves.easeOutCubic.transform(ramp(age, 0.55, 0.95));
    final paper = Rect.fromLTWH(24, picture.bottom + 12 + 40 * (1 - slide), _w - 48, paperH);
    final paperFade = slide * (1 - outro);
    drawPaper(canvas, paper, Memories.all.indexOf(memory) * 37 + 5, alpha: paperFade);
    var chars = state.memoryTyped ? 1 << 20 : ((age - 0.8) * 30).floor(); // about 30 letters a second
    for (var i = 0; i < lines.length && chars > 0; i++) {
      final line = lines[i];
      final visible = line.substring(0, math.min(line.length, chars));
      chars -= line.length + 1;
      PixelFont.draw(canvas, visible, _w / 2 - PixelFont.widthOf(line, 2) / 2, paper.top + 12 + i * 19, 2,
          Palette.ink.withValues(alpha: paperFade));
    }

    if (state.readingMemory && state.memoryTyped && state.memoryOutro < 0 && blinkOn(state.time)) {
      PixelFont.drawCentered(canvas, state.touchUi ? 'TAP TO CONTINUE' : 'CLICK TO CONTINUE', _w / 2, paper.bottom + 14,
          2, Palette.parchment, shadow: Palette.ink);
    }
  }

  /// A coin and "SHOP". When something new is affordable, the edge turns gold and a dot blinks.
  void _shopButton(Canvas canvas, Rect rect, GameState state) {
    final news = game.canBuySomething;
    drawPanel(canvas, rect, edge: news ? Palette.sun : Palette.panelEdge);
    drawCoin(canvas, Offset(rect.left + 17, rect.center.dy), 7);
    PixelFont.draw(canvas, 'SHOP', rect.left + 32, rect.top + 9, 2, news ? Palette.sun : Palette.text);
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

    final number = '${state.meters}';
    final labelW = PixelFont.widthOf('METERS', 2), numberW = PixelFont.widthOf(number, 6);
    final boxW = math.max(labelW, numberW) + 20;
    final boxX = _w - 10 - boxW;
    drawPanel(canvas, Rect.fromLTWH(boxX, top, boxW, 78));
    PixelFont.draw(canvas, 'METERS', boxX + boxW - 10 - labelW, top + 10, 2, Palette.muted);
    PixelFont.draw(canvas, number, boxX + boxW - 10 - numberW, top + 28, 6,
        state.popTime > 0 ? Palette.sun : Palette.text,
        shadow: Palette.hot);

    // left column: best run, then the coin total
    var leftY = top;
    if (state.best > 0) {
      const label = 'BEST ';
      final value = '${state.best}M';
      drawPanel(canvas, Rect.fromLTWH(10, leftY, PixelFont.widthOf(label + value, 2) + 16, 26));
      PixelFont.draw(canvas, label, 18, leftY + 6, 2, Palette.muted);
      PixelFont.draw(canvas, value, 18 + label.length * 12, leftY + 6, 2, Palette.sun);
      leftY += 32;
    }
    final coinText = '${state.coins}';
    drawPanel(canvas, Rect.fromLTWH(10, leftY, 36 + PixelFont.widthOf(coinText, 2), 26));
    drawCoin(canvas, Offset(24, leftY + 13), 7);
    PixelFont.draw(canvas, coinText, 37, leftY + 6, 2, state.coinPopTime > 0 ? Palette.sun : Palette.text);
    final match = game.match;
    if (match != null && state.versus) _friendPanel(canvas, state, match, leftY + 32, top);

    // right column, under the meters: the shield
    if (state.shield) {
      final rect = Rect.fromLTWH(_w - 40, top + 86, 30, 30);
      drawPanel(canvas, rect);
      drawPowerUp(canvas, rect.center, PowerUp.shield, 10);
    }

    if (state.mode == GameMode.playing && !state.holding && !state.readingMemory && blinkOn(state.time)) {
      const hint = 'HOLD TO STEER';
      final w = PixelFont.widthOf(hint, 2) + 20;
      final y = state.height - 50 - game.safeBottom;
      drawPanel(canvas, Rect.fromLTWH((_w - w) / 2, y, w, 28));
      PixelFont.drawCentered(canvas, hint, _w / 2, y + 7, 2, Palette.sun);
    }

    if (state.mode == GameMode.playing && state.realmCardTime > 0 && !state.readingMemory) _realmCard(canvas, state);

    if (state.toastTime > 0) {
      // long messages shrink to fit the field
      final px = math.min(4.0, (_w - 24) / (state.toast.length * 6 - 1));
      PixelFont.drawCentered(canvas, state.toast, _w / 2, state.height * 0.27 - (1.6 - state.toastTime) * 20, px,
          Palette.sun,
          shadow: Palette.ink);
    }
  }

  /// "ENTERING" and the realm's name, fading in and out between two little diamonds.
  void _realmCard(Canvas canvas, GameState state) {
    final shown = GameState.realmCardSeconds - state.realmCardTime;
    final alpha = math.min(1.0, math.min(shown / 0.5, state.realmCardTime / 0.8));
    final name = GameState.realms[state.realm].name;
    final y = state.height * 0.36 - shown * 6; // drifts gently upward
    PixelFont.drawCentered(canvas, 'ENTERING', _w / 2, y, 2, Palette.muted.withValues(alpha: alpha));
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
    // best run and coins on one line, between the call to action and the buttons
    final best = state.best > 0 ? 'BEST ${state.best}M' : '';
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
    PixelFont.drawCentered(canvas, state.spooked ? 'GOT YOU.' : 'BONK!', _w / 2, top, state.spooked ? 8 : 10, Palette.hot,
        shadow: Palette.ink);
    if (state.realm > 0) {
      _glitchText(canvas, 'IN ${GameState.realms[state.realm].name}', top + 84, 2, Palette.glimmer, Palette.ink,
          state.time, ramp(game.corruption, 0.3, 1) * 0.5);
    }

    final panelY = top + 110;
    drawPanel(canvas, Rect.fromLTWH(52, panelY, _w - 104, 236));
    PixelFont.drawCentered(canvas, 'YOU FLEW', _w / 2, panelY + 20, 2, Palette.muted);
    PixelFont.drawCentered(canvas, '${state.meters}', _w / 2, panelY + 46, 10, Palette.text, shadow: Palette.hot);
    PixelFont.drawCentered(canvas, 'METERS', _w / 2, panelY + 132, 2, Palette.muted);
    _coinLine(canvas, '+${_coinCount(state.runCoins)}', panelY + 160, Palette.sun);
    if (state.newBest && state.meters > 0) {
      if (blinkOn(state.time)) PixelFont.drawCentered(canvas, 'NEW BEST!', _w / 2, panelY + 190, 4, Palette.sun);
    } else {
      PixelFont.drawCentered(canvas, 'BEST ${state.best}M', _w / 2, panelY + 198, 2, Palette.muted);
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
