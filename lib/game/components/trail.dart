import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// The rainbow trail, following the bunny's actual flight path (loops and dives included).
/// The path is softened, each stripe is offset along the path's normal so the ribbon keeps
/// its width through turns, and it is drawn oldest piece first so newer loops pass over older
/// ones. World coordinates: (x, -worldY).
class Trail extends Component with HasGameReference<GoingUpGame> {
  Trail() : super(priority: 0);

  static final List<Paint> _stripePaints = [
    for (final color in Palette.rainbow)
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GameState.trailStripe + 0.9 // a little overlap hides seams between stripes
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.butt
        ..color = color,
  ];

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final src = state.trail;
    final alive = state.mode != GameMode.dead;
    final n = src.length + (alive ? 1 : 0);
    if (n < 2) return;

    final xs = List<double>.filled(n, 0), ys = List<double>.filled(n, 0);
    final ids = List<int>.filled(n, 0);
    for (var i = 0; i < src.length; i++) {
      xs[i] = src[i].x;
      ys[i] = -src[i].wy;
      ids[i] = src[i].id;
    }
    if (alive) {
      xs[n - 1] = state.bunnyX;
      ys[n - 1] = -state.tailWorldY;
      ids[n - 1] = src.isEmpty ? 0 : src.last.id + 1;
    }

    // soften the path with two passes of a [1 2 1] filter; the ends stay put
    for (var pass = 0; pass < 2; pass++) {
      var px = xs[0], py = ys[0];
      for (var i = 1; i < n - 1; i++) {
        final cx = xs[i], cy = ys[i];
        xs[i] = (px + 2 * cx + xs[i + 1]) / 4;
        ys[i] = (py + 2 * cy + ys[i + 1]) / 4;
        px = cx;
        py = cy;
      }
    }

    // unit normals pointing to the ribbon's red side, from the direction a few points either side
    final nx = List<double>.filled(n, 1), ny = List<double>.filled(n, 0);
    var lastX = 1.0, lastY = 0.0;
    for (var i = 0; i < n; i++) {
      final a = math.max(0, i - 2), b = math.min(n - 1, i + 2);
      final dx = xs[b] - xs[a], dy = ys[b] - ys[a];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 1e-3) {
        lastX = -dy / len;
        lastY = dx / len;
      }
      nx[i] = lastX;
      ny[i] = lastY;
    }

    // a gentle travelling wave, fading out where the trail meets the bunny
    final wave = List<double>.generate(
        n, (i) => 1.4 * math.sin(ids[i] * 0.45 - state.time * 6) * math.min(1.0, (n - 1 - i) / 8));

    const chunk = 16;
    for (var start = 0; start < n - 1; start += chunk) {
      final from = math.max(0, start - 1); // overlap one segment so pieces join without a seam
      final to = math.min(n - 1, start + chunk);
      for (var k = 0; k < 6; k++) {
        final offset = -GameState.trailWidth / 2 + (k + 0.5) * GameState.trailStripe;
        final path = Path();
        for (var i = from; i <= to; i++) {
          final o = offset + wave[i];
          final x = xs[i] + nx[i] * o, y = ys[i] + ny[i] * o;
          if (i == from) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, _stripePaints[k]);
      }
    }
  }
}
