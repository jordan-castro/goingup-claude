import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// The Hollow Ones: what's left of Pip's family. Each is Pip's own pixel-art body gone wrong
/// (see `Sprites.hollow`): ash-grey with a blood-red outline, one ear torn, one glowing red eye
/// and a button for the other, a stitched grin full of teeth, tattered wings. They twitch,
/// crouch before they leap (the eye flares), and squash and stretch as they hop. World
/// coordinates: (x, -worldY). Only the body counts for being caught; the ears, wings and the
/// leap are just for show.
class HollowLayer extends Component with HasGameReference<GoingUpGame> {
  HollowLayer() : super(priority: 2);

  /// One sprite pixel: a little bigger than Pip's.
  static const double _px = 2.5;

  final _pixels = Paint()..filterQuality = FilterQuality.none;
  final _glow = Paint();

  @override
  void render(Canvas canvas) {
    final state = game.state;
    if (state.hollows.isEmpty) return;
    for (final g in state.hollows) {
      final sy = state.screenY(g.wy);
      if (sy < -70 || sy > state.height + 50) continue;
      _draw(canvas, g, Offset(g.x, -g.wy), state.time + g.phase * 3);
    }
  }

  void _draw(Canvas canvas, Hollow g, Offset base, double t) {
    final sprites = game.sprites.hollow;

    // a red glow that throbs, stronger as it gets ready to leap
    final throb = 0.5 + 0.5 * math.sin(t * 5);
    _glow.color = Palette.hollowRim.withValues(alpha: 0.1 + 0.08 * throb + 0.22 * g.crouch + 0.08 * game.mood);
    canvas.drawCircle(base + const Offset(0, -6), 30 + 4 * throb, _glow);

    // a twitch now and then: a sharp little jerk
    final beat = (t * 1.1).floor();
    final twitch = hash01(beat * 13 + 5) < 0.45 && (t * 1.1 - beat) < 0.08 ? (hash01(beat) - 0.5) * 0.4 : 0.0;

    canvas.save();
    canvas.translate(base.dx, base.dy + 6 * _px - 8 * g.hop); // feet down, the leap only for show
    canvas.rotate(twitch + g.facing * 0.14 * g.hop);
    final squash = 1 - 0.25 * g.crouch + 0.16 * g.hop;
    canvas.scale(1 / math.sqrt(squash), squash);
    canvas.translate(0, -6 * _px);

    // wings beating in jerky, uneven strokes
    final up = hash01((t * 7).floor() + 3) < 0.5;
    void image(Image image, double x, double y) {
      final w = image.width.toDouble(), h = image.height.toDouble();
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h), Rect.fromLTWH(x * _px, y * _px, w * _px, h * _px), _pixels);
    }

    image(up ? sprites.wingUpLeft : sprites.wingDownLeft, -14, -1);
    image(up ? sprites.wingUpRight : sprites.wingDownRight, 7, -1);
    image(sprites.bunny, -8, -14);

    // the eye glows, flaring as it crouches
    final glare = 0.5 + 0.3 * throb + 0.6 * g.crouch;
    _glow.color = Palette.hollowEye.withValues(alpha: 0.35 * math.min(1.0, glare));
    canvas.drawCircle(const Offset(-4 * _px, -3 * _px), 3 * _px, _glow);
    canvas.restore();
  }
}
