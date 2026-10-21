import 'dart:ui';

import 'palette.dart';

/// The two shelves of the coin shop.
enum Shelf { bunnies, trails }

/// What a skin or trail does besides look good. Only items costing more than
/// [Shop.perksAbove] coins have one.
enum Perk {
  none(''),
  headStart('STARTS 50% FASTER'),
  startShield('STARTS WITH A SHIELD'),
  hollowProof('HOLLOW ONES PASS THROUGH'),
  magnet('PULLS IN NEARBY COINS'),
  doubleCoins('EVERY COIN COUNTS TWICE'),
  secondChance('ONE CRASH A RUN FORGIVEN');

  const Perk(this.description);

  /// Upper case, in the pixel font's characters, and short enough for the shop's preview.
  final String description;
}

/// Something the coin shop sells. The first item on each shelf is free and owned from the start.
sealed class ShopItem {
  const ShopItem(this.id, this.name, this.price, this.perk);

  /// Saved on the device, so never rename one.
  final String id;
  final String name;
  final int price;
  final Perk perk;

  Shelf get shelf;
}

/// A bunny colouring: the pixel-art palette used for the body and wings.
class BunnySkin extends ShopItem {
  const BunnySkin(
    String id,
    String name,
    int price, {
    Perk perk = Perk.none,
    this.outline = Palette.ink,
    required this.fur,
    required this.belly,
    required this.ear,
    required this.cheek,
    required this.nose,
    required this.mouth,
    required this.wing,
  }) : super(id, name, price, perk);

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
  const TrailStyle(String id, String name, int price, this.stripes, {Perk perk = Perk.none})
      : super(id, name, price, perk);

  final List<Color> stripes;

  @override
  Shelf get shelf => Shelf.trails;
}

/// Everything for sale, cheapest first on each shelf.
abstract final class Shop {
  /// Items costing more than this come with a [Perk].
  static const perksAbove = 2000;

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
    BunnySkin('peach', 'PEACH', 150,
        fur: Color(0xFFF9C9A7),
        belly: Color(0xFFFDE6D2),
        ear: Color(0xFFF2A07B),
        cheek: Color(0xFFEE8C70),
        nose: Color(0xFFD9654A),
        mouth: Color(0xFFA2483A),
        wing: Color(0xFFFBE3A0)),
    BunnySkin('cocoa', 'COCOA', 250,
        fur: Color(0xFFB98762),
        belly: Color(0xFFEACDAA),
        ear: Color(0xFFEBA9A2),
        cheek: Color(0xFFDB8578),
        nose: Color(0xFF7A4630),
        mouth: Color(0xFF5A321F),
        wing: Color(0xFFF4E4C8)),
    BunnySkin('storm', 'STORM', 350,
        fur: Color(0xFF9AA6B8),
        belly: Color(0xFFC9D1DC),
        ear: Color(0xFFD7A8C0),
        cheek: Color(0xFFC88EAE),
        nose: Color(0xFF6D7890),
        mouth: Color(0xFF4E566A),
        wing: Color(0xFFD8E8F5)), // grey as a rain cloud
    BunnySkin('mint', 'MINT', 500,
        fur: Color(0xFFBDEBD6),
        belly: Color(0xFFE8F8F0),
        ear: Color(0xFFF2A9C6),
        cheek: Color(0xFFF08FB0),
        nose: Color(0xFFDE608C),
        mouth: Color(0xFFA8527A),
        wing: Color(0xFFA9D6F6)),
    BunnySkin('lilac', 'LILAC', 750,
        fur: Color(0xFFCDB8F0),
        belly: Color(0xFFEADFFB),
        ear: Color(0xFFF2A9D2),
        cheek: Color(0xFFEC93C2),
        nose: Color(0xFFB05FA0),
        mouth: Color(0xFF7E4378),
        wing: Color(0xFFF7C7E3)),
    BunnySkin('midnight', 'MIDNIGHT', 1000,
        outline: Color(0xFFD4C8FA), // a light outline and glowing eyes, so it shows in the dark
        fur: Color(0xFF3C3568),
        belly: Color(0xFF59518E),
        ear: Color(0xFFB98CE8),
        cheek: Color(0xFF8E6CD0),
        nose: Color(0xFFECCC62),
        mouth: Color(0xFFC9B8F2),
        wing: Color(0xFF8FE3E0)),
    BunnySkin('ember', 'EMBER', 1500,
        outline: Color(0xFF3A1408),
        fur: Color(0xFFD9583A),
        belly: Color(0xFFF3A16E),
        ear: Color(0xFFF7C35A),
        cheek: Color(0xFFF28C3C),
        nose: Color(0xFF7A1F12),
        mouth: Color(0xFF5A170D),
        wing: Color(0xFFFFD27A)),
    BunnySkin('golden', 'GOLDEN', 2000,
        outline: Color(0xFF4A2E10),
        fur: Color(0xFFF2CF63),
        belly: Color(0xFFFBE8A8),
        ear: Color(0xFFF5B38A),
        cheek: Color(0xFFF09A6E),
        nose: Color(0xFFC9733A),
        mouth: Color(0xFF9A5A2A),
        wing: Color(0xFFFFF7DC)),
    // from here on, every skin does something
    BunnySkin('comet', 'COMET', 2500,
        perk: Perk.headStart,
        outline: Color(0xFF1C2B48),
        fur: Color(0xFF8FD3F2),
        belly: Color(0xFFD9F2FC),
        ear: Color(0xFFF5B3D7),
        cheek: Color(0xFFF29BC8),
        nose: Color(0xFF3B6FA8),
        mouth: Color(0xFF2B4F7A),
        wing: Color(0xFFFFFFFF)),
    BunnySkin('guardian', 'GUARDIAN', 4000,
        perk: Perk.startShield,
        outline: Color(0xFF2A2340),
        fur: Color(0xFFC9CED8),
        belly: Color(0xFFEEF1F6),
        ear: Color(0xFFB48CE0),
        cheek: Color(0xFFC99BE8),
        nose: Color(0xFF6A4FA0),
        mouth: Color(0xFF4A3878),
        wing: Color(0xFFD8C2F5)), // silver, with the shield's purple
    BunnySkin('phantom', 'PHANTOM', 6000,
        perk: Perk.hollowProof,
        outline: Color(0xFFC9F2EC), // light outline, so it shows in the dark
        fur: Color(0xFF2B3A3A),
        belly: Color(0xFF3E5654),
        ear: Color(0xFF7FE0D2),
        cheek: Color(0xFF59BFB2),
        nose: Color(0xFF9FE8DC),
        mouth: Color(0xFF7FE0D2),
        wing: Color(0xFF6FD8C8)),
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
    TrailStyle('sunset', 'SUNSET', 150, [
      Color(0xFFF06C5C),
      Color(0xFFF5915A),
      Color(0xFFF7B55E),
      Color(0xFFF2CF7A),
      Color(0xFFE3A0C8),
      Color(0xFFB78AD8),
    ]),
    TrailStyle('ocean', 'OCEAN', 250, [
      Color(0xFF235FA8),
      Color(0xFF2F84C8),
      Color(0xFF45ACD6),
      Color(0xFF6ECFD6),
      Color(0xFFA6E8DA),
      Color(0xFFE2FAF2),
    ]),
    TrailStyle('lavender', 'LAVENDER', 350, [
      Color(0xFF8E6CD0),
      Color(0xFFA688DD),
      Color(0xFFBEA4E8),
      Color(0xFFD4C0F2),
      Color(0xFFE7DCF8),
      Color(0xFFF6F0FD),
    ]),
    TrailStyle('fire', 'FIRE', 500, [
      Color(0xFF9A1F30),
      Color(0xFFCC3530),
      Color(0xFFE8642E),
      Color(0xFFF2923A),
      Color(0xFFF6C04C),
      Color(0xFFFBE69A),
    ]),
    TrailStyle('mono', 'MONO', 750, [
      Color(0xFF2A2A2E),
      Color(0xFF4A4A52),
      Color(0xFF7A7A84),
      Color(0xFFA8A8B2),
      Color(0xFFD2D2D8),
      Color(0xFFF6F6F8),
    ]),
    TrailStyle('aurora', 'AURORA', 1000, [
      Color(0xFF2E8C7A),
      Color(0xFF3FC29A),
      Color(0xFF86E2B4),
      Color(0xFF8C74E2),
      Color(0xFFB27EE8),
      Color(0xFFE07CC8),
    ]),
    TrailStyle('neon', 'NEON', 1500, [
      Color(0xFFFF2D95),
      Color(0xFFFF7A2D),
      Color(0xFFF8F32B),
      Color(0xFF2DFF8C),
      Color(0xFF2DD4FF),
      Color(0xFFB42DFF),
    ]),
    TrailStyle('gold', 'GOLD', 2000, [
      Color(0xFF9A6A1E),
      Color(0xFFC99A2E),
      Color(0xFFE6BE48),
      Color(0xFFF5D873),
      Color(0xFFFAEAAE),
      Color(0xFFFFF8E2),
    ]),
    // from here on, every trail does something
    TrailStyle('magnet', 'MAGNET', 2500, perk: Perk.magnet, [
      Color(0xFFC0392B),
      Color(0xFFE74C3C),
      Color(0xFFECF0F1),
      Color(0xFFBDC3C7),
      Color(0xFF3498DB),
      Color(0xFF2C80B9),
    ]),
    TrailStyle('lucky', 'LUCKY', 4000, perk: Perk.doubleCoins, [
      Color(0xFF1E8449),
      Color(0xFF27AE60),
      Color(0xFF58D68D),
      Color(0xFFF4D03F),
      Color(0xFFF9E79F),
      Color(0xFFFEF9E7),
    ]),
    TrailStyle('phoenix', 'PHOENIX', 6000, perk: Perk.secondChance, [
      Color(0xFF5B0E2D),
      Color(0xFFA61E4D),
      Color(0xFFE8433F),
      Color(0xFFF59E42),
      Color(0xFFFCD34D),
      Color(0xFFFFF7D6),
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
