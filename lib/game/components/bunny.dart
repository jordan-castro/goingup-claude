import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';

/// The bunny: a pixel-art body, two flapping wings and, while the shield is on, a bubble.
/// Positioned at the bunny's anchor (sprite column 8, row 14) in world coordinates.
class BunnyView extends PositionComponent with HasGameReference<GoingUpGame>, HasVisibility {
  BunnyView() : super(priority: 5);

  static const double _bp = GameState.bunnyPixel;

  late final PositionComponent _sprite; // body and wings, moved together for the bob
  late final SpriteComponent _body;
  late final SpriteAnimationComponent _leftWing, _rightWing;
  late final SpriteAnimation _slowFlapLeft, _fastFlapLeft, _slowFlapRight, _fastFlapRight;
  late final _ShieldBubble _shield;
  bool? _fastFlap;

  @override
  Future<void> onLoad() async {
    final sprites = game.sprites;
    SpriteAnimation flap(Image up, Image down, double step) =>
        SpriteAnimation.spriteList([Sprite(up), Sprite(down)], stepTime: step);
    _slowFlapLeft = flap(sprites.wingUpLeft, sprites.wingDownLeft, 0.25);
    _fastFlapLeft = flap(sprites.wingUpLeft, sprites.wingDownLeft, 0.1);
    _slowFlapRight = flap(sprites.wingUpRight, sprites.wingDownRight, 0.25);
    _fastFlapRight = flap(sprites.wingUpRight, sprites.wingDownRight, 0.1);

    final wingSize = Vector2(7 * _bp, 10 * _bp);
    _leftWing = SpriteAnimationComponent(animation: _slowFlapLeft, position: Vector2(-14 * _bp, -1 * _bp), size: wingSize);
    _rightWing = SpriteAnimationComponent(animation: _slowFlapRight, position: Vector2(7 * _bp, -1 * _bp), size: wingSize);
    _body = SpriteComponent(sprite: Sprite(sprites.bunny), position: Vector2(-8 * _bp, -14 * _bp), size: Vector2(16 * _bp, 25 * _bp));
    for (final c in <HasPaint>[_leftWing, _rightWing, _body]) {
      c.paint.filterQuality = FilterQuality.none; // keep the pixels square
    }
    _sprite = PositionComponent(children: [_leftWing, _rightWing, _body]);
    _shield = _ShieldBubble();
    addAll([_sprite, _shield]);
  }

  @override
  void update(double dt) {
    final state = game.state;
    isVisible = state.mode != GameMode.dead;
    position.setValues(state.bunnyX, -state.worldY(state.bunnyY));

    final title = state.mode == GameMode.title;
    _sprite.position.y = title ? math.sin(state.time * 3) * 6 : math.sin(state.time * 11) * 1.5;
    final fast = !title;
    if (fast != _fastFlap) {
      _fastFlap = fast;
      _leftWing.animation = fast ? _fastFlapLeft : _slowFlapLeft;
      _rightWing.animation = fast ? _fastFlapRight : _slowFlapRight;
    }

    final blink = state.mode == GameMode.playing && state.grace > 0 && (state.time * 16).floor().isEven;
    final opacity = blink ? 0.45 : 1.0;
    for (final c in <HasPaint>[_leftWing, _rightWing, _body]) {
      c.opacity = opacity;
    }
    _shield.isVisible = state.shield;
    super.update(dt);
  }
}

class _ShieldBubble extends PositionComponent with HasGameReference<GoingUpGame>, HasVisibility {
  _ShieldBubble() : super(position: Vector2(0, 2));

  final _fill = Paint()..color = Palette.shield.withValues(alpha: 0.12);
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = Palette.shield.withValues(alpha: 0.75);

  @override
  void render(Canvas canvas) {
    final r = 34 + math.sin(game.state.time * 4) * 1.5;
    canvas.drawCircle(Offset.zero, r, _fill);
    canvas.drawCircle(Offset.zero, r, _ring);
  }
}
