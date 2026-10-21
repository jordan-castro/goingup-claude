import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import 'trail.dart';

/// The friend in a two-player race: their bunny and trail, in their skin and trail style, at
/// half opacity. Can't be touched: it's only a picture. World coordinates, like the bunny.
class GhostView extends Component with HasGameReference<GoingUpGame> {
  GhostView() : super(priority: 4);

  static const double _bp = GameState.bunnyPixel;
  static const double opacity = 0.5;

  final _layer = Paint()..color = const Color.fromRGBO(0, 0, 0, opacity);
  final _pixels = Paint()..filterQuality = FilterQuality.none;
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = Palette.shield;
  final List<Paint> _stripes = [
    for (var k = 0; k < 6; k++)
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GameState.trailStripe + 0.9
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.butt,
  ];

  @override
  void render(Canvas canvas) {
    final match = game.match;
    if (match == null || !match.ghostVisible) return;
    final time = game.state.time;
    // drawn whole, then faded as one, so overlapping stripes and wings don't show through
    canvas.saveLayer(null, _layer);

    final points = match.ghostTrail;
    if (points.length >= 2) {
      final style = Shop.trail(match.friendTrail ?? '');
      for (var k = 0; k < 6; k++) {
        _stripes[k].color = style.stripes[k];
      }
      drawRibbon(canvas, [for (final p in points) p.$1], [for (final p in points) -p.$2], [for (final p in points) p.$3],
          _stripes, time);
    }

    final sprites = game.sprites.skin(Shop.skin(match.friendSkin ?? ''));
    final at = Offset(match.ghostX, -match.ghostWy + math.sin(time * 11) * 1.5);
    final up = (time * 10).floor().isEven;
    _image(canvas, up ? sprites.wingUpLeft : sprites.wingDownLeft, at, -14, -1);
    _image(canvas, up ? sprites.wingUpRight : sprites.wingDownRight, at, 7, -1);
    _image(canvas, sprites.bunny, at, -8, -14);
    if (match.ghostShield) canvas.drawCircle(at + const Offset(0, 2), 34 + math.sin(time * 4) * 1.5, _ring);
    canvas.restore();
  }

  /// [image] placed [x], [y] sprite pixels from the bunny's anchor at [at].
  void _image(Canvas canvas, Image image, Offset at, double x, double y) {
    final w = image.width.toDouble(), h = image.height.toDouble();
    canvas.drawImageRect(
        image, Rect.fromLTWH(0, 0, w, h), Rect.fromLTWH(at.dx + x * _bp, at.dy + y * _bp, w * _bp, h * _bp), _pixels);
  }
}
