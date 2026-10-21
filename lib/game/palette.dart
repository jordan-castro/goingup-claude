import 'dart:ui';

import 'game_state.dart' show PowerUp;

/// Matte colours shared by the game and its painter: flat fills, no glows.
abstract final class Palette {
  static const coin = Color(0xFFE8BE48);
  static const coinRim = Color(0xFFB0832A);
  static const boost = Color(0xFFE6944E);
  static const slow = Color(0xFF549CD4);
  static const freeze = Color(0xFF7CCFE0);
  static const shield = Color(0xFFC98AE0);

  static Color powerUp(PowerUp p) => switch (p) {
        PowerUp.boost => boost,
        PowerUp.slow => slow,
        PowerUp.freeze => freeze,
        PowerUp.shield => shield,
      };

  static const page = Color(0xFF0C0A1A); // letterbox around the play field
  static const space = Color(0xFF1B1A38);

  // Night: what the climb fades into as it gets harder.
  static const spaceNight = Color(0xFF09060F);
  static const starNight = Color(0xFFC4B5FF);
  static const rim = Color(0xFF8C79C9); // moonlit wall edge
  static const mistViolet = Color(0xFF6B3FA0);
  static const mistTeal = Color(0xFF2C8C8A);
  static const glimmer = Color(0xFF9FE8DC);
  static const fog = Color(0xFF8C7FD0);
  static const shade = Color(0xFF000000);
  static const ink = Color(0xFF221834);
  static const star = Color(0xFFD6D6EC);
  static const panel = Color(0xD9120F26);
  static const panelEdge = Color(0xFFCEC8E8);
  static const text = Color(0xFFF2EEFA);
  static const muted = Color(0xFFB0A8D0);
  static const sun = Color(0xFFECCC62);
  static const hot = Color(0xFFD65C8C);
  static const line = Color(0xFFD6D0EC);

  static const rainbow = [
    Color(0xFFDA5660),
    Color(0xFFE6944E),
    Color(0xFFE4CC56),
    Color(0xFF6EBA6C),
    Color(0xFF549CD4),
    Color(0xFF8C72CE),
  ];
  static const logo = [...rainbow, Color(0xFFDE78B8)];
  static const sprinkles = [
    Color(0xFFCE506E),
    Color(0xFFDEBA50),
    Color(0xFF50B496),
    Color(0xFF4E96CE),
    Color(0xFF966EC8),
    Color(0xFFF0ECF8),
    Color(0xFFDC8250),
  ];
  static const ghostSpark = [
    Color(0xFFDCE4FA),
    Color(0xFFCEB8F6),
    Color(0xFFECCC62),
    Color(0xFFF2EEFA),
  ];
}
