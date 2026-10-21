import 'dart:ui';

import 'palette.dart';

/// The two shelves of the coin shop.
enum Shelf { bunnies, trails }

/// Something the coin shop sells. The first item on each shelf is free and owned from the start.
sealed class ShopItem {
  const ShopItem(this.id, this.name, this.price);

  /// Saved on the device, so never rename one.
  final String id;
  final String name;
  final int price;

  Shelf get shelf;
}

/// A bunny colouring: the pixel-art palette used for the body and wings.
class BunnySkin extends ShopItem {
  const BunnySkin(
    super.id,
    super.name,
    super.price, {
    this.outline = Palette.ink,
    required this.fur,
    required this.belly,
    required this.ear,
    required this.cheek,
    required this.nose,
    required this.mouth,
    required this.wing,
  });

  /// [outline] also colours the eyes.
  final Color outline, fur, belly, ear, cheek, nose, mouth, wing;

  @override
  Shelf get shelf => Shelf.bunnies;

  /// Colours by sprite letter (see `Sprites`).
  Map<String, Color> get palette =>
      {'k': outline, 'w': fur, 'g': belly, 'p': ear, 'c': cheek, 'n': nose, 'm': mouth, 'b': wing};
}

/// The six stripes of the bunny's trail, outermost first.
class TrailStyle extends ShopItem {
  const TrailStyle(super.id, super.name, super.price, this.stripes);

  final List<Color> stripes;

  @override
  Shelf get shelf => Shelf.trails;
}

/// Everything for sale, cheapest first on each shelf.
abstract final class Shop {
  static const skins = <BunnySkin>[
    BunnySkin('snowball', 'SNOWBALL', 0,
        fur: Color(0xFFF6F4FA),
        belly: Color(0xFFE0DAF0),
        ear: Color(0xFFEEA4C8),
        cheek: Color(0xFFEC96BA),
        nose: Color(0xFFDE608C),
        mouth: Color(0xFFA8527A),
        wing: Color(0xFFC0E0F2)),
    BunnySkin('berry', 'BERRY', 100,
        fur: Color(0xFFF5B8D0),
        belly: Color(0xFFFCE4EE),
        ear: Color(0xFFE0688F),
        cheek: Color(0xFFE2557F),
        nose: Color(0xFFC63D62),
        mouth: Color(0xFF94304F),
        wing: Color(0xFF9ED68F)), // leafy wings, like a strawberry top
    BunnySkin('cocoa', 'COCOA', 250,
        fur: Color(0xFFB98762),
        belly: Color(0xFFEACDAA),
        ear: Color(0xFFEBA9A2),
        cheek: Color(0xFFDB8578),
        nose: Color(0xFF7A4630),
        mouth: Color(0xFF5A321F),
        wing: Color(0xFFF4E4C8)),
    BunnySkin('mint', 'MINT', 500,
        fur: Color(0xFFBDEBD6),
        belly: Color(0xFFE8F8F0),
        ear: Color(0xFFF2A9C6),
        cheek: Color(0xFFF08FB0),
        nose: Color(0xFFDE608C),
        mouth: Color(0xFFA8527A),
        wing: Color(0xFFA9D6F6)),
    BunnySkin('midnight', 'MIDNIGHT', 1000,
        outline: Color(0xFFD4C8FA), // a light outline and glowing eyes, so it shows in the dark
        fur: Color(0xFF3C3568),
        belly: Color(0xFF59518E),
        ear: Color(0xFFB98CE8),
        cheek: Color(0xFF8E6CD0),
        nose: Color(0xFFECCC62),
        mouth: Color(0xFFC9B8F2),
        wing: Color(0xFF8FE3E0)),
    BunnySkin('golden', 'GOLDEN', 2000,
        outline: Color(0xFF4A2E10),
        fur: Color(0xFFF2CF63),
        belly: Color(0xFFFBE8A8),
        ear: Color(0xFFF5B38A),
        cheek: Color(0xFFF09A6E),
        nose: Color(0xFFC9733A),
        mouth: Color(0xFF9A5A2A),
        wing: Color(0xFFFFF7DC)),
  ];

  static const trails = <TrailStyle>[
    TrailStyle('rainbow', 'RAINBOW', 0, Palette.rainbow),
    TrailStyle('candy', 'CANDY', 100, [
      Color(0xFFF59ABF),
      Color(0xFFF8BCD4),
      Color(0xFFFCE0EC),
      Color(0xFFD4EAFB),
      Color(0xFFAED5F6),
      Color(0xFF8DC0EE),
    ]),
    TrailStyle('ocean', 'OCEAN', 250, [
      Color(0xFF235FA8),
      Color(0xFF2F84C8),
      Color(0xFF45ACD6),
      Color(0xFF6ECFD6),
      Color(0xFFA6E8DA),
      Color(0xFFE2FAF2),
    ]),
    TrailStyle('fire', 'FIRE', 500, [
      Color(0xFF9A1F30),
      Color(0xFFCC3530),
      Color(0xFFE8642E),
      Color(0xFFF2923A),
      Color(0xFFF6C04C),
      Color(0xFFFBE69A),
    ]),
    TrailStyle('aurora', 'AURORA', 1000, [
      Color(0xFF2E8C7A),
      Color(0xFF3FC29A),
      Color(0xFF86E2B4),
      Color(0xFF8C74E2),
      Color(0xFFB27EE8),
      Color(0xFFE07CC8),
    ]),
    TrailStyle('gold', 'GOLD', 2000, [
      Color(0xFF9A6A1E),
      Color(0xFFC99A2E),
      Color(0xFFE6BE48),
      Color(0xFFF5D873),
      Color(0xFFFAEAAE),
      Color(0xFFFFF8E2),
    ]),
  ];

  static BunnySkin get defaultSkin => skins.first;
  static TrailStyle get defaultTrail => trails.first;

  static List<ShopItem> shelf(Shelf shelf) => switch (shelf) {
        Shelf.bunnies => skins,
        Shelf.trails => trails,
      };

  /// The skin or trail with [id], or the free one if there's no such item (any more).
  static BunnySkin skin(String id) => skins.firstWhere((s) => s.id == id, orElse: () => defaultSkin);
  static TrailStyle trail(String id) => trails.firstWhere((t) => t.id == id, orElse: () => defaultTrail);

  static bool exists(String id) => skins.any((s) => s.id == id) || trails.any((t) => t.id == id);
}
