import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';

/// Keeps one [PickupComponent] per coin or power-up in the game state: new pickups get a
/// component, collected or passed ones lose theirs.
class PickupLayer extends Component with HasGameReference<GoingUpGame> {
  PickupLayer() : super(priority: 2);

  final Map<Pickup, PickupComponent> _shown = HashMap.identity();

  @override
  void update(double dt) {
    final live = game.state.pickups;
    final liveSet = HashSet<Pickup>.identity()..addAll(live);
    _shown.removeWhere((pickup, component) {
      if (liveSet.contains(pickup)) return false;
      component.removeFromParent();
      return true;
    });
    for (final pickup in live) {
      if (_shown.containsKey(pickup)) continue;
      final component = PickupComponent(pickup);
      _shown[pickup] = component;
      add(component);
    }
  }

  int get shownCount => _shown.length;
}

/// A spinning coin, a bobbing power-up badge or a glowing memory fragment, placed at its
/// world position.
class PickupComponent extends PositionComponent with HasGameReference<GoingUpGame> {
  PickupComponent(this.pickup) : super(position: Vector2(pickup.x, -pickup.wy));

  final Pickup pickup;

  @override
  void render(Canvas canvas) {
    final t = game.state.time;
    final power = pickup.powerUp;
    if (pickup.memory != null) {
      drawFragment(canvas, Offset(0, math.sin(t * 2 + pickup.phase) * 4), t + pickup.phase, 11);
    } else if (power == null) {
      drawCoin(canvas, Offset.zero, 8, spin: math.cos(t * 3 + pickup.phase));
    } else {
      drawPowerUp(canvas, Offset(0, math.sin(t * 3 + pickup.phase) * 3), power, 13);
    }
  }
}
