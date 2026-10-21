import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import '../sprites.dart';

/// The coin shop, opened from the title and game-over screens: a shelf of bunny skins and one
/// of trails, six to a page, a big preview of the selected item (with what it does, for the
/// dearest ones), and a button to buy or wear it. Drawn in field coordinates over everything
/// but the speaker button.
class ShopScreen extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  bool isOpen = false;
  Shelf shelf = Shelf.bunnies;
  ShopItem selected = Shop.defaultSkin;
  int page = 0;
  static const perPage = 6;
  double _cheer = 0; // celebration after a purchase, in seconds left

  final _pixels = Paint()..filterQuality = FilterQuality.none;
  final _stripe = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  void open() {
    isOpen = true;
    _show(Shelf.bunnies);
  }

  void close() => isOpen = false;

  void _show(Shelf next) {
    shelf = next;
    final items = Shop.shelf(next);
    final worn = items.indexWhere(game.state.isWearing);
    _select(items[worn]);
    page = worn ~/ perPage;
  }

  int get pages => (Shop.shelf(shelf).length + perPage - 1) ~/ perPage;

  /// The items on the page showing.
  List<ShopItem> get _pageItems => Shop.shelf(shelf).skip(page * perPage).take(perPage).toList();

  void _select(ShopItem item) {
    if (item != selected) _cheer = 0; // the celebration belongs to the item just bought
    selected = item;
  }

  // ---------- layout (field units) ----------

  /// Top of the shop, which is 586 tall: centred when the screen has room to spare.
  double get _top {
    final top = 10 + game.safeTop;
    final spare = (game.state.height - game.safeBottom - 12) - (top + 586);
    return top + math.max(0.0, spare / 2);
  }

  Rect tab(Shelf s) => Rect.fromLTWH(s == Shelf.bunnies ? 16 : 204, _top + 50, 180, 36);
  Rect get preview => Rect.fromLTWH(16, _top + 96, _w - 32, 150);
  Rect card(int i) => Rect.fromLTWH(16 + (i % 3) * (352 / 3 + 8), _top + 256 + (i ~/ 3) * 98, 352 / 3, 90);
  Rect get prevPage => Rect.fromLTWH(16, _top + 452, 56, 28);
  Rect get nextPage => Rect.fromLTWH(_w - 72, _top + 452, 56, 28);
  Rect get actionButton => Rect.fromLTWH(16, _top + 488, _w - 32, 48);
  Rect get backButton => Rect.fromLTWH((_w - 140) / 2, _top + 546, 140, 40);

  // ---------- input ----------

  /// A press at [p] (field units) while the shop is open.
  void press(Offset p) {
    bool hit(Rect r) => r.inflate(4).contains(p);
    for (final s in Shelf.values) {
      if (hit(tab(s))) {
        if (s != shelf) _show(s);
        _sound(Sfx.click);
        return;
      }
    }
    final items = _pageItems;
    for (var i = 0; i < items.length; i++) {
      if (hit(card(i))) {
        _select(items[i]);
        _sound(Sfx.click);
        return;
      }
    }
    if (hit(prevPage) && page > 0) {
      page--;
      _sound(Sfx.click);
    } else if (hit(nextPage) && page < pages - 1) {
      page++;
      _sound(Sfx.click);
    } else if (hit(actionButton)) {
      _act();
    } else if (hit(backButton)) {
      close();
      _sound(Sfx.click);
    }
  }

  /// Wears the selected item if it's owned, buys it if there are enough coins.
  void _act() {
    final state = game.state, item = selected;
    if (state.isWearing(item)) return;
    if (state.owns(item)) {
      state.wear(item);
      _sound(Sfx.click);
    } else if (state.buy(item)) {
      _cheer = 1.4;
      _sound(Sfx.buy);
    } else {
      _sound(Sfx.nope);
    }
  }

  void _sound(Sfx sfx) => game.sfx.play(SoundCue(sfx));

  @override
  void update(double dt) {
    _cheer = math.max(0.0, _cheer - dt);
  }

  // ---------- drawing ----------

  @override
  void render(Canvas canvas) {
    if (!isOpen) return;
    final state = game.state;
    final t = state.time;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, state.height), Paint()..color = Palette.page.withValues(alpha: 0.9));

    final top = _top;
    PixelFont.draw(canvas, 'SHOP', 16, top + 2, 5, Palette.text, shadow: Palette.hot);
    final coinText = '${state.coins}';
    final coinW = 36 + PixelFont.widthOf(coinText, 2);
    drawPanel(canvas, Rect.fromLTWH(_w - 16 - coinW, top + 6, coinW, 26));
    drawCoin(canvas, Offset(_w - 16 - coinW + 14, top + 19), 7);
    PixelFont.draw(canvas, coinText, _w - 16 - coinW + 27, top + 12, 2, _cheer > 0 ? Palette.sun : Palette.text);

    for (final s in Shelf.values) {
      final rect = tab(s), active = s == shelf;
      drawPanel(canvas, rect, edge: active ? Palette.sun : Palette.panelEdge);
      PixelFont.drawCentered(canvas, s == Shelf.bunnies ? 'BUNNIES' : 'TRAILS', rect.center.dx, rect.top + 11, 2,
          active ? Palette.sun : Palette.muted);
    }

    _preview(canvas, state, t);

    final items = _pageItems;
    for (var i = 0; i < items.length; i++) {
      _card(canvas, state, card(i), items[i], t);
    }
    _pager(canvas);

    _action(canvas, state);

    final back = backButton;
    drawPanel(canvas, back);
    PixelFont.drawCentered(canvas, 'BACK', back.center.dx, back.top + 11, 3, Palette.text);
  }

  void _preview(Canvas canvas, GameState state, double t) {
    final rect = preview;
    drawPanel(canvas, rect, edge: _cheer > 0 && blinkOn(t * 2) ? Palette.sun : Palette.panelEdge);
    final skin = selected is BunnySkin ? selected as BunnySkin : state.skin;
    final trail = selected is TrailStyle ? selected as TrailStyle : state.trailStyle;

    // the bunny flying in place, its trail streaming down to the bottom of the panel
    const s = 3.0;
    final anchor = Offset(rect.left + 92, rect.top + 56 + math.sin(t * 3) * 4);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5)));
    _trail(canvas, trail, anchor + const Offset(0, 8 * s), rect.bottom, s, t);
    _bunny(canvas, game.sprites.skin(skin), anchor, s, wingsUp: (t * 5).floor().isEven);
    if (_cheer > 0) _sparkles(canvas, anchor + const Offset(0, 4 * s), t);
    canvas.restore();

    final x = rect.left + 186;
    PixelFont.draw(canvas, selected.shelf == Shelf.bunnies ? 'BUNNY' : 'TRAIL', x, rect.top + 20, 2, Palette.muted);
    PixelFont.draw(canvas, selected.name, x, rect.top + 40, 3, Palette.text, shadow: Palette.ink);
    _status(canvas, state, selected, x, rect.top + 72, 2, align: 0);
    if (_cheer > 0) PixelFont.draw(canvas, 'YAY!', x, rect.top + 94, 3, Palette.sun, shadow: Palette.hot);

    // what it does, on a band across the bottom
    final perk = selected.perk;
    if (perk != Perk.none) {
      final band = Rect.fromLTWH(rect.left + 6, rect.bottom - 34, rect.width - 12, 28);
      drawPanel(canvas, band, edge: Palette.glimmer);
      final w = 20 + PixelFont.widthOf(perk.description, 2);
      final left = band.center.dx - w / 2;
      _perkStar(canvas, Offset(left + 6, band.center.dy), 6, t);
      PixelFont.draw(canvas, perk.description, left + 20, band.top + 7, 2, Palette.glimmer);
    }
  }

  /// A four-pointed twinkle marking an item with a perk.
  void _perkStar(Canvas canvas, Offset p, double size, double t) {
    final s = size * (0.85 + 0.15 * math.sin(t * 5));
    canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
          ..close(),
        Paint()..color = Palette.glimmer);
  }

  /// Arrows to turn the page, and a dot for each page.
  void _pager(Canvas canvas) {
    if (pages < 2) return;
    final arrow = Paint()..color = Palette.text;
    for (final (rect, dir, on) in [(prevPage, -1.0, page > 0), (nextPage, 1.0, page < pages - 1)]) {
      if (!on) continue;
      drawPanel(canvas, rect);
      final c = rect.center;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx + dir * 7, c.dy)
            ..lineTo(c.dx - dir * 5, c.dy - 8)
            ..lineTo(c.dx - dir * 5, c.dy + 8)
            ..close(),
          arrow);
    }
    final y = prevPage.center.dy;
    for (var i = 0; i < pages; i++) {
      final x = _w / 2 + (i - (pages - 1) / 2) * 18;
      canvas.drawCircle(Offset(x, y), i == page ? 5 : 3.5, Paint()..color = i == page ? Palette.sun : Palette.muted);
    }
  }

  void _card(Canvas canvas, GameState state, Rect rect, ShopItem item, double t) {
    final chosen = item == selected;
    drawPanel(canvas, rect, edge: chosen ? Palette.sun : Palette.panelEdge);
    if (chosen) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(4)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Palette.sun.withValues(alpha: 0.5));
    }
    final c = rect.center.dx;
    switch (item) {
      case BunnySkin():
        // whole sprite (rows 0-24) centred in the top part of the card
        const s = 1.5;
        _bunny(canvas, game.sprites.skin(item), Offset(c, rect.top + 28 + 1.5 * s), s, wingsUp: false);
      case TrailStyle():
        _arc(canvas, item, Offset(c, rect.top + 46), 24);
    }
    if (item.perk != Perk.none) _perkStar(canvas, rect.topRight + const Offset(-12, 12), 6, t);
    PixelFont.drawCentered(canvas, item.name, c, rect.top + 54, 2, Palette.text);
    _status(canvas, state, item, c, rect.top + 71, 2, align: 0.5);
  }

  /// "WEARING", "OWNED" or a coin and the price (gold when it's affordable). [align] 0 puts
  /// the line's left edge at [x], 0.5 centres it there.
  void _status(Canvas canvas, GameState state, ShopItem item, double x, double y, double px, {required double align}) {
    if (state.isWearing(item) || state.owns(item)) {
      final wearing = state.isWearing(item);
      final text = wearing ? 'WEARING' : 'OWNED';
      PixelFont.draw(canvas, text, x - PixelFont.widthOf(text, px) * align, y, px, wearing ? Palette.sun : Palette.muted);
      return;
    }
    final text = '${item.price}';
    final w = 7 * px + 4 + PixelFont.widthOf(text, px);
    final left = x - w * align;
    drawCoin(canvas, Offset(left + 3.5 * px, y + 3.5 * px), 3.5 * px);
    PixelFont.draw(canvas, text, left + 7 * px + 4, y, px, state.canAfford(item) ? Palette.sun : Palette.muted);
  }

  void _action(Canvas canvas, GameState state) {
    final rect = actionButton, item = selected;
    final c = rect.center.dx, y = rect.top + 13;
    if (state.isWearing(item)) {
      drawPanel(canvas, rect);
      PixelFont.drawCentered(canvas, 'WEARING', c, y, 3, Palette.muted);
    } else if (state.owns(item)) {
      drawPanel(canvas, rect, edge: Palette.sun);
      PixelFont.drawCentered(canvas, 'WEAR IT', c, y, 3, Palette.sun);
    } else if (state.canAfford(item)) {
      drawPanel(canvas, rect, edge: Palette.sun);
      final price = '${item.price}';
      final w = PixelFont.widthOf('BUY', 3) + 14 + 22 + PixelFont.widthOf(price, 3);
      final left = c - w / 2;
      PixelFont.draw(canvas, 'BUY', left, y, 3, Palette.sun);
      drawCoin(canvas, Offset(left + PixelFont.widthOf('BUY', 3) + 14 + 10, y + 10), 10);
      PixelFont.draw(canvas, price, left + PixelFont.widthOf('BUY', 3) + 36, y, 3, Palette.sun);
    } else {
      drawPanel(canvas, rect);
      PixelFont.drawCentered(canvas, 'NEED ${item.price - state.coins} MORE COINS', c, rect.top + 17, 2, Palette.muted);
    }
  }

  /// The bunny's sprite at scale [s], placed by its anchor (sprite column 8, row 14).
  void _bunny(Canvas canvas, BunnySprites sprites, Offset anchor, double s, {required bool wingsUp}) {
    void image(Image image, double x, double y) {
      final w = image.width.toDouble(), h = image.height.toDouble();
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h),
          Rect.fromLTWH(anchor.dx + x * s, anchor.dy + y * s, w * s, h * s), _pixels);
    }

    image(wingsUp ? sprites.wingUpLeft : sprites.wingDownLeft, -14, -1);
    image(wingsUp ? sprites.wingUpRight : sprites.wingDownRight, 7, -1);
    image(sprites.bunny, -8, -14);
  }

  /// A trail hanging from [from] down to [bottom], waving gently, stripes as wide as in the game.
  void _trail(Canvas canvas, TrailStyle style, Offset from, double bottom, double s, double t) {
    final width = 2 * s; // two sprite pixels per stripe
    _stripe.strokeWidth = width + 0.9;
    for (var k = 0; k < 6; k++) {
      final path = Path();
      for (var y = from.dy; y <= bottom + 4; y += 3) {
        final settle = math.min(1.0, (y - from.dy) / 24); // the wave fades out at the bunny
        final x = from.dx + (k - 2.5) * width + math.sin(y * 0.06 - t * 6) * 3.5 * settle;
        if (y == from.dy) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      _stripe.color = style.stripes[k];
      canvas.drawPath(path, _stripe);
    }
  }

  /// A little rainbow arch in the trail's stripes, outermost stripe on the outside.
  void _arc(Canvas canvas, TrailStyle style, Offset base, double radius) {
    const band = 3.6;
    _stripe.strokeWidth = band + 0.6;
    for (var k = 0; k < 6; k++) {
      final r = radius - (k + 0.5) * band;
      _stripe.color = style.stripes[k];
      canvas.drawArc(Rect.fromCircle(center: base, radius: r), math.pi, math.pi, false, _stripe);
    }
  }

  /// Twinkles circling the bunny after a purchase.
  void _sparkles(Canvas canvas, Offset c, double t) {
    final paint = Paint()..color = Palette.sun.withValues(alpha: math.min(1.0, _cheer * 2));
    for (var i = 0; i < 8; i++) {
      final a = t * 1.5 + i * math.pi / 4;
      final r = 52 + math.sin(t * 5 + i) * 6;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r * 0.8);
      final size = 3.0 + (i % 3);
      canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - size * 1.6)
            ..quadraticBezierTo(p.dx, p.dy, p.dx + size * 1.6, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + size * 1.6)
            ..quadraticBezierTo(p.dx, p.dy, p.dx - size * 1.6, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - size * 1.6)
            ..close(),
          paint);
    }
  }
}
