import 'dart:ui';

import 'drawing.dart';

/// How much of each realm's look is showing, from the run's (eased) mood and depth. Each
/// realm hands over to the next, so at most two show at once and their shares add up to 1:
///
/// * candy: the bright pastel start;
/// * wallpaper: Twilight, the old burrow's peeling wallpaper and family portraits;
/// * rust: Ashfall, rusted mesh and falling ash;
/// * hollow: The Hollow, black stone, roots, chalk scrawls and hands in the fog;
/// * abyss: The Void, black flesh with pulsing red veins and teeth along the edges.
class Stages {
  Stages(double mood, double deep)
      : _a = ramp(mood, 0.1, 0.22),
        _b = ramp(mood, 0.36, 0.46),
        _c = ramp(mood, 0.58, 0.68),
        _d = ramp(deep, 0, 0.4);

  final double _a, _b, _c, _d;

  double get candy => 1 - _a;
  double get wallpaper => _a * (1 - _b);
  double get rust => _b * (1 - _c);
  double get hollow => _c * (1 - _d);
  double get abyss => _d;

  /// From Ashfall on: the realms where things start to fall apart.
  double get dread => _b;

  /// The colour for each realm, mixed by how much each is showing.
  Color mix(Color candy, Color wallpaper, Color rust, Color hollow, Color abyss) =>
      Color.lerp(Color.lerp(Color.lerp(Color.lerp(candy, wallpaper, _a)!, rust, _b)!, hollow, _c)!, abyss, _d)!;
}
