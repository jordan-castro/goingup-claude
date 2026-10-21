/// Knobs for goingUP's level design and power-ups. Change the defaults here, or pass your own
/// [GameTuning] to `Game` (the tests do that to make things happen sooner).
class GameTuning {
  const GameTuning({
    this.bonusZoneEvery = const int.fromEnvironment('BONUS_ZONE_EVERY', defaultValue: 10),
    this.bonusZoneSeconds = 3.5,
    this.openSectionChance = 0.1,
    this.powerUpChance = 0.05,
    this.shieldHitSlowFactor = 0.5,
    this.shieldHitSlowSeconds = 2,
    this.darkestAtScreen = 45,
    this.deepestAtScreen = 60,
    this.hollowsFromScreen = 25,
    this.hollowsCommonAtScreen = 45,
    this.hollowChance = 0.75,
    this.memoryChance = 0.15,
  });

  /// A wide-open bonus stretch full of coins starts every this many screens. 0 turns it off.
  /// Also settable per build: `flutter run --dart-define=BONUS_ZONE_EVERY=3`.
  final int bonusZoneEvery;

  /// How long a bonus stretch lasts, in seconds at the speed you're flying when it's built.
  final double bonusZoneSeconds;

  /// Chance that the next stretch of ordinary tunnel opens up wide (with a short line of
  /// coins). It doesn't shrink as the game speeds up, so wide spots keep coming.
  final double openSectionChance;

  /// Chance that a stretch of ordinary tunnel holds a shield (the only power-up).
  final double powerUpChance;

  /// When the shield takes a hit, the level runs at this fraction of its speed for
  /// [shieldHitSlowSeconds], then catches back up in a quarter of that time.
  final double shieldHitSlowFactor;
  final double shieldHitSlowSeconds;
  double get shieldRecoverSeconds => shieldHitSlowSeconds / 4;

  /// The run gets darker and more mystic (picture and music) as you climb, reaching full
  /// darkness at this screen. Difficulty tops out at screen 40. The realms along the way
  /// (`GameState.realms`) are spaced out up to here.
  final double darkestAtScreen;

  /// Past full darkness the run sinks further into the Void (the moon is eclipsed, the walls
  /// go nearly black and eyes open in them), as deep as it goes at this screen.
  final double deepestAtScreen;

  /// Hollows (spiky shadow puffs that drift across the tunnel) start turning up at
  /// [hollowsFromScreen] and are at their most common by [hollowsCommonAtScreen], when a
  /// stretch of tunnel wide enough to hold one gets one with chance [hollowChance] (wide spots
  /// too). 0 turns them off.
  final int hollowsFromScreen, hollowsCommonAtScreen;
  final double hollowChance;

  /// Chance that a stretch of ordinary tunnel holds the next forgotten memory fragment of the
  /// realm the run is in (at most one per realm per run).
  final double memoryChance;
}
