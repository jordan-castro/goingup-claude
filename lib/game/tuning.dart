/// Knobs for goingUP's level design and power-ups. Change the defaults here, or pass your own
/// [GameTuning] to `GameState` (the tests do that to make things happen sooner).
///
/// Distances are in in-game meters: the bunny is half a meter long.
class GameTuning {
  const GameTuning({
    this.bonusZoneEveryMeters = const int.fromEnvironment('BONUS_ZONE_EVERY_METERS', defaultValue: 130),
    this.bonusZoneSeconds = 2,
    this.openSectionChance = 0.04,
    this.powerUpChance = 0.05,
    this.shieldHitSlowFactor = 0.5,
    this.shieldHitSlowSeconds = 2,
    this.realmEveryMeters = const int.fromEnvironment('REALM_EVERY_METERS', defaultValue: 130),
    this.voidDeepensOverMeters = 150,
    this.hardestAtMeters = 260,
    this.hollowsFromRealm = 2,
    this.hollowsCommonAtRealm = 4,
    this.hollowChance = 0.9,
    this.hollowNestEveryMeters = 40,
    this.milestoneEveryMeters = 100,
  });

  /// A wide-open bonus stretch full of coins starts every this many meters, the first one half
  /// as far in: with the realms as far apart, that's halfway through each realm, clear of the
  /// memory forks. 0 turns it off.
  /// Also settable per build: `flutter run --dart-define=BONUS_ZONE_EVERY_METERS=20`.
  final int bonusZoneEveryMeters;

  /// How long a bonus stretch lasts, in seconds at the speed flown there.
  final double bonusZoneSeconds;

  /// Chance that the next stretch of ordinary tunnel opens into a short wide pocket (with a
  /// line of coins), at any speed. Kept low: the tunnel is mostly corridor.
  final double openSectionChance;

  /// Chance that a stretch of ordinary tunnel holds a shield (the only power-up).
  final double powerUpChance;

  /// When the shield takes a hit, the level runs at this fraction of its speed for
  /// [shieldHitSlowSeconds], then catches back up in a quarter of that time.
  final double shieldHitSlowFactor;
  final double shieldHitSlowSeconds;
  double get shieldRecoverSeconds => shieldHitSlowSeconds / 4;

  /// The realms (`GameState.realms`) start this far apart: Twilight at 1x, Ashfall at 2x,
  /// The Hollow at 3x and The Void at 4x. The run is fully dark on reaching the Void.
  /// Also settable per build: `flutter run --dart-define=REALM_EVERY_METERS=20`.
  final int realmEveryMeters;

  /// Past full darkness the run sinks further into the Void (the moon is eclipsed, the walls
  /// go nearly black and eyes open in them), as deep as it goes this many meters in.
  final double voidDeepensOverMeters;

  /// The tunnel is at its narrowest and twistiest from here on.
  final double hardestAtMeters;

  /// The Hollow Ones turn up from the start of realm [hollowsFromRealm] (2 is Ashfall). They
  /// only ever wait in open space, never in a narrow corridor: every [hollowNestEveryMeters]
  /// the corridor opens into a short pocket where one waits, and a random wide pocket holds one
  /// with a chance growing to [hollowChance] by the start of realm [hollowsCommonAtRealm], as
  /// does the chance of a second one in the same pocket. A [hollowChance] of 0 turns them off.
  final int hollowsFromRealm, hollowsCommonAtRealm;
  final double hollowChance;
  final double hollowNestEveryMeters;

  /// "100 METERS!" every this many meters.
  final int milestoneEveryMeters;
}
