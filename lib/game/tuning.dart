/// Knobs for goingUP's level design and power-ups. Change the defaults here, or pass your own
/// [GameTuning] to `Game` (the tests do that to make things happen sooner).
class GameTuning {
  const GameTuning({
    this.bonusZoneEvery = const int.fromEnvironment('BONUS_ZONE_EVERY', defaultValue: 10),
    this.bonusZoneSeconds = 3.5,
    this.openSectionChance = 0.1,
    this.powerUpChance = 0.14,
    this.boostFactor = 1.25,
    this.slowFactor = 0.8,
    this.boostSeconds = 6,
    this.slowSeconds = 6,
    this.freezeSeconds = 3,
    this.shieldHitSlowFactor = 0.5,
    this.shieldHitSlowSeconds = 2,
    this.darkestAtScreen = 45,
  });

  /// A wide-open bonus stretch full of coins starts every this many screens. 0 turns it off.
  /// Also settable per build: `flutter run --dart-define=BONUS_ZONE_EVERY=3`.
  final int bonusZoneEvery;

  /// How long a bonus stretch lasts, in seconds at the speed you're flying when it's built.
  final double bonusZoneSeconds;

  /// Chance that the next stretch of ordinary tunnel opens up wide (with a short line of
  /// coins). It doesn't shrink as the game speeds up, so wide spots keep coming.
  final double openSectionChance;

  /// Chance that a stretch of ordinary tunnel holds a power-up.
  final double powerUpChance;

  /// Boost multiplies the level speed. 1.25 turns 10 seconds per screen into 8.
  final double boostFactor;

  /// Slow multiplies the level speed. 0.8 is 20% slower.
  final double slowFactor;

  /// How long each timed power-up lasts. Freeze stops the level completely.
  final double boostSeconds, slowSeconds, freezeSeconds;

  /// When the shield takes a hit, the level runs at this fraction of its speed for
  /// [shieldHitSlowSeconds], then catches back up in a quarter of that time.
  final double shieldHitSlowFactor;
  final double shieldHitSlowSeconds;
  double get shieldRecoverSeconds => shieldHitSlowSeconds / 4;

  /// The run gets darker and more mystic (picture and music) as you climb, reaching full
  /// darkness at this screen. Difficulty tops out at screen 40.
  final double darkestAtScreen;
}
