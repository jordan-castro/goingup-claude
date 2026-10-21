import 'dart:math' as math;
import 'dart:ui' show Color;

import 'memories.dart';
import 'palette.dart';
import 'shop.dart';
import 'tuning.dart';

export 'memories.dart';
export 'shop.dart';
export 'tuning.dart';

/// Which screen the game is showing.
enum GameMode { title, playing, dead }

/// Collectible power-ups. Only the shield is left: it waits for a hit.
enum PowerUp { shield }

/// Sound effects. Coins also carry a step: a quick run of them climbs the scale.
enum Sfx {
  coin, shield, bump, crash, takeoff, ghost, milestone, newBest, hollowPop, realm, memory, glitch,
  click, buy, nope, // shop buttons
}

/// One layer of the climb. Each is darker and more mystic than the last. A run enters realm i
/// at i x [GameTuning.realmEveryMeters]; [from] is the darkness ([GameState.mood]) it starts
/// at, which the picture and music are tuned to.
class Realm {
  const Realm(this.name, this.from);

  final String name;
  final double from;
}

/// A sound for the view to play.
class SoundCue {
  const SoundCue(this.sfx, [this.step = 0]);

  final Sfx sfx;
  final int step;

  @override
  String toString() => step == 0 ? sfx.name : '${sfx.name}$step';
}

/// What survives between sessions.
class SavedProgress {
  const SavedProgress({
    this.best = 0,
    this.coins = 0,
    this.lastMeters,
    this.crashY,
    this.crashX,
    this.owned = const [],
    this.skin,
    this.trail,
    this.memories = const [],
  });

  /// Most meters flown in one run.
  final int best;

  /// Coins in the bank.
  final int coins;

  /// Meters flown in the last run, and where (world height and x) it ended.
  final int? lastMeters;
  final double? crashY;
  final double? crashX;

  /// Ids of the shop items bought, and of the skin and trail being worn.
  final List<String> owned;
  final String? skin, trail;

  /// Ids of the memories Pip has got back.
  final List<String> memories;
}

/// One point of the bunny's flight path, in world coordinates. World y grows upward, so a
/// dive shows up as points whose [wy] goes down again.
class TrailPoint {
  const TrailPoint(this.x, this.wy, this.id);

  final double x;
  final double wy;
  final int id;
}

class WallSample {
  const WallSample(this.wy, this.left, this.right, this.id);

  final double wy;
  final double left;
  final double right;
  final int id;
}

/// A coin, power-up or memory floating in the tunnel, in world coordinates. Coins can move
/// (the magnet pulls them in).
class Pickup {
  Pickup.coin(this.x, this.wy, this.phase)
      : powerUp = null,
        memory = null,
        group = null;
  Pickup.powerUp(this.x, this.wy, PowerUp this.powerUp, this.phase)
      : memory = null,
        group = null;

  /// A memory: a realm's own memory (an old photograph) or one of its fragments (a torn shard
  /// of the burrow wall). Pickups sharing a [group] are a choice: taking one loses the others.
  Pickup.memory(this.x, this.wy, Memory this.memory, this.phase, {this.group}) : powerUp = null;

  double x, wy;
  final double phase;
  final PowerUp? powerUp;
  final Memory? memory;
  final int? group;

  bool get isCoin => powerUp == null && memory == null;

  /// A realm's own memory, as opposed to one of its fragments.
  bool get isRealmMemory => memory?.arrival ?? false;
}

/// One of the Hollow Ones: an evil copy of Pip that hops from side to side across a stretch of
/// open space late in a run. Touching one ends the run, unless the shield takes the hit.
class Hollow {
  Hollow(this.wy, this.centre, this.reach, this.rate, this.phase) : x = centre;

  /// Body size. The ears stick up further, and the bunny is only caught well inside.
  static const double radius = 13, hitRadius = 10;

  final double wy, centre, reach, rate, phase;

  /// Where it is now. It never overlaps the walls.
  double x;

  /// It doesn't drift, it hops: it crouches ([crouch] 0 to 1, a warning), then leaps
  /// ([hop] 0 to 1 and back) to its next spot, toward [facing] (-1 left, 1 right).
  double crouch = 0, hop = 0, facing = 1;
}

/// A puff of particles the view should show, in world coordinates.
class Burst {
  const Burst(this.x, this.wy, this.count, this.colors, this.minSpeed, this.maxSpeed);

  final double x, wy;
  final int count;
  final List<Color> colors;
  final double minSpeed, maxSpeed;
}

/// Where the previous run crashed, shown during the next run.
class CrashMarker {
  CrashMarker(this.wy, this.x);

  final double wy, x;
  double fade = 1;
  bool passed = false;
}

class _Control {
  const _Control(this.wy, this.centre, this.gap);

  final double wy, centre, gap;
}

/// goingUP's rules and state. No rendering or engine code, so it can be tested on its own;
/// the Flame game reads it every frame.
///
/// Units: the play field is always [width] wide; its [height] follows the screen's shape.
/// World y grows upward and [distance] is how far the field has scrolled. The bunny is half a
/// meter long, which makes [unitsPerMeter].
///
/// The tunnel depends only on the run's seed and the height reached, never on how fast it was
/// flown or the screen's shape, so two players given the same [runSeed] fly the same tunnel.
class GameState {
  GameState({int? seed, this.tuning = const GameTuning(), this.onSave, this.onCrash, this.onBump})
      : _rng = math.Random(seed),
        _forkRng = math.Random(seed == null ? null : seed + 7919) {
    _resetWorld();
  }

  static const double width = 400;
  static const double minHeight = 640, maxHeight = 870;
  static const double defaultHeight = 720;
  static const double bunnyPixel = 2.2; // size of one bunny sprite pixel
  static const double bunnyLength = 25 * bunnyPixel; // the whole sprite, ears to feet

  /// The bunny is half a meter long.
  static const double unitsPerMeter = bunnyLength / 0.5;

  static const double trailStripe = 4.4;
  static const double trailWidth = trailStripe * 6;
  static const double trailTailOffset = 8 * bunnyPixel; // trail leaves from the bunny's feet
  static const double overDelay = 0.45, retryDelay = 0.95;

  static const double _baseSpeed = 190, _maxSpeed = 1250;
  static const double _follow = 15; // how snappily the bunny chases the pointer
  static const double _step = 8; // spacing of wall samples
  static const double _wideGap = width - 40;
  static const double _passage = 56; // room a hollow always leaves on one side
  static const double _hollowMinGap = 2 * (Hollow.radius + _passage) + 2;
  static const double _maxHollowDrift = 150; // fastest sideways speed, units per second
  static const double _forkGap = 330, _forkLength = 560, _forkSpread = 95;
  static const double _magnetReach = 110;
  static const double _headStartFactor = 1.5;
  static const int _maxTrail = 900;
  static const int _maxBursts = 40;
  static const int _maxSounds = 16;
  static const int coinSteps = 5;
  static const double _coinRunGap = 0.5; // coins closer together than this climb the scale

  final GameTuning tuning;
  math.Random _rng;
  math.Random _forkRng; // separate: what a fork holds depends on the player, the tunnel mustn't

  /// When set, every run starts its tunnel from this seed (a versus match: both players fly
  /// the same tunnel). Otherwise each run carries on from the last.
  int? runSeed;

  /// Called when something worth saving changes (a crash, a coin). Callers may batch writes.
  void Function(SavedProgress progress)? onSave;
  void Function()? onCrash;

  /// Called when the shield (or a second chance) takes a hit.
  void Function()? onBump;

  GameMode mode = GameMode.title;
  double time = 0, runTime = 0, distance = 0, speed = 110;

  /// Meters flown this run, and the most in any run.
  int meters = 0, best = 0;
  bool newBest = false;
  int? lastMeters;

  /// The run ended on a hollow rather than a wall.
  bool spooked = false;

  /// Part of a versus match: memories don't pause the run (they wait in the book), there's no
  /// "last crash" ghost, and a new run starts only when the match says so.
  bool versus = false;

  /// The run was stopped by the match (the other player crashed) rather than by a crash.
  bool endedByMatch = false;

  /// The layers of the climb, from the bright start to the Void.
  static const realms = [
    Realm('RAINBOW SKY', 0),
    Realm('TWILIGHT', 0.18),
    Realm('ASHFALL', 0.4),
    Realm('THE HOLLOW', 0.62),
    Realm('THE VOID', 1),
  ];
  static const double realmCardSeconds = 2.8;

  /// Index into [realms] of the one the run has reached (kept through the game-over screen),
  /// and how long its "ENTERING" card has left on screen.
  int realm = 0;
  double realmCardTime = 0;

  /// Ids of the memories Pip has got back, the one coming back right now and how long it has
  /// been showing, and whether any came back since the memories book was last opened.
  final Set<String> memories = {};
  Memory? shownMemory;
  double memoryAge = 0;
  bool newMemories = false;

  /// Whether a memory pauses the run until the player continues. The app turns this on;
  /// without it (as in most tests) a memory shows for [memorySeconds] while the run goes on.
  bool pauseForMemories = false;
  static const double memorySeconds = 6;

  /// Seconds into closing the memory (the ink drawing back into the bunny), or -1.
  double memoryOutro = -1;
  static const double memoryOutroSeconds = 0.6;
  final List<Memory> _waitingMemories = []; // came back while another was being read
  final Set<int> _forksPlanned = {}; // realms whose memory fork is in the tunnel this run
  int _groupId = 0;

  /// Coins in the bank (collected, less what was spent in the shop), and the ones from this run.
  int coins = 0, runCoins = 0;

  /// Shop items bought (free ones aren't listed), and the skin and trail being worn.
  final Set<String> owned = {};
  String skinId = Shop.defaultSkin.id, trailStyleId = Shop.defaultTrail.id;
  BunnySkin get skin => Shop.skin(skinId);
  TrailStyle get trailStyle => Shop.trail(trailStyleId);

  /// What the skin and trail being worn do.
  bool hasPerk(Perk perk) => skin.perk == perk || trailStyle.perk == perk;

  bool shield = false;

  /// The phoenix trail's forgiven crash, while it's still unused this run.
  bool spareLife = false;

  /// Show touch wording ("touch and hold") instead of mouse wording.
  bool touchUi = false;

  double bunnyX = width / 2, bunnyY = defaultHeight * 0.7;
  double _targetX = width / 2, _targetY = defaultHeight * 0.7;
  bool holding = false;
  double _touchOffset = 0;
  double grace = 0, deadTime = 0, shake = 0, popTime = 0, coinPopTime = 0;
  String toast = '';
  double toastTime = 0;

  double _hitTime = -1; // seconds since the shield took a hit, or -1

  final List<_Control> _controls = [];
  final List<_Control> _queued = []; // planned stretches (bonus zones, open sections, forks)
  int _ctrlIdx = 0;
  double _nextZoneWy = double.infinity;
  final List<WallSample> walls = [];
  int _sampleId = 0;
  double _nextW = 0, _wobble = 0;

  final List<TrailPoint> trail = [];
  int _trailId = 0;
  final List<Pickup> pickups = [];
  final List<Hollow> hollows = [];
  double _hollowClock = 0; // drives the hopping; stands still while the level is slowed
  bool _warnedHollows = false;

  /// Particle puffs waiting for the view to show them. The view empties this list.
  final List<Burst> bursts = [];

  /// Sounds waiting for the view to play them. The view empties this list.
  final List<SoundCue> sounds = [];
  int _coinStep = 0;
  double _lastCoinTime = -1;

  double? _crashY, _crashX;
  CrashMarker? marker;

  double _height = defaultHeight;
  double get height => _height;
  set height(double value) => _height = value.clamp(minHeight, maxHeight);

  bool get showGameOver => mode == GameMode.dead && deadTime >= overDelay;
  bool get canRetry => mode == GameMode.dead && deadTime > retryDelay && !versus;

  /// Field y (0 at the top of the screen) of world height [wy].
  double screenY(double wy) => height - (wy - distance);

  /// World height of field y [y].
  double worldY(double y) => distance + height - y;

  double get tailWorldY => worldY(bunnyY + trailTailOffset);

  /// World height where realm [r] begins.
  double realmStart(int r) => r * tuning.realmEveryMeters * unitsPerMeter;

  /// How far along the realms world height [wy] is: realm i begins at i.
  double _realmProgress(double wy) => wy / unitsPerMeter / tuning.realmEveryMeters;

  /// How far the run has sunk into darkness: 0 is the bright start (and the title screen),
  /// 1 is full night on reaching the Void. Realm i begins when it reaches `realms[i].from`;
  /// in between it grows steadily. Keeps its value through the game-over screen and drops
  /// back to 0 when a new run starts.
  double get mood {
    if (mode == GameMode.title) return 0;
    final r = _realmProgress(distance);
    if (r >= realms.length - 1) return 1;
    final i = r.floor();
    return _lerp(realms[i].from, realms[i + 1].from, r - i);
  }

  /// How far past full darkness the run has sunk into the Void: 0 until the Void, 1 once
  /// [GameTuning.voidDeepensOverMeters] in. Like [mood], it keeps its value through the
  /// game-over screen and drops back to 0 when a new run starts.
  double get deep {
    if (mode == GameMode.title) return 0;
    final into = distance / unitsPerMeter - (realms.length - 1) * tuning.realmEveryMeters;
    if (tuning.voidDeepensOverMeters <= 0) return into >= 0 ? 1 : 0;
    return (into / tuning.voidDeepensOverMeters).clamp(0.0, 1.0);
  }

  /// Level speed before a shield hit slows it: slow at first, then faster.
  double get baseSpeed => baseSpeedAfter(runTime);

  static double baseSpeedAfter(double seconds) =>
      math.min(_maxSpeed, _baseSpeed + 4 * seconds + 0.075 * seconds * seconds);

  /// Seconds of flying before the base speed reaches [speed].
  static double _secondsToSpeed(double speed) {
    final c = _baseSpeed - math.min(speed, _maxSpeed);
    return (-4 + math.sqrt(16 - 4 * 0.075 * c)) / (2 * 0.075);
  }

  /// The base speed a run normally has by the time it reaches world height [wy]: the tunnel
  /// is built for that, so it's the same whoever flies it and however fast.
  static double expectedSpeedAt(double wy) {
    double flown(double t) => _baseSpeed * t + 2 * t * t + 0.025 * t * t * t;
    final top = _secondsToSpeed(_maxSpeed), topDistance = flown(top);
    if (wy >= topDistance) return _maxSpeed;
    var lo = 0.0, hi = top;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (flown(mid) < wy) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return baseSpeedAfter((lo + hi) / 2);
  }

  /// How much a shield hit is scaling the level speed right now.
  double get levelFactor => _hitFactor;

  double get _hitFactor {
    if (_hitTime < 0) return 1;
    final slow = tuning.shieldHitSlowSeconds;
    if (_hitTime < slow) return tuning.shieldHitSlowFactor;
    final t = (_hitTime - slow) / tuning.shieldRecoverSeconds;
    return t >= 1 ? 1 : _lerp(tuning.shieldHitSlowFactor, 1, t);
  }

  SavedProgress get progress => SavedProgress(
        best: best,
        coins: coins,
        lastMeters: lastMeters,
        crashY: _crashY,
        crashX: _crashX,
        owned: owned.toList()..sort(),
        skin: skinId,
        trail: trailStyleId,
        memories: memories.toList()..sort(),
      );

  void restore(SavedProgress saved) {
    best = math.max(best, saved.best);
    coins += saved.coins; // keeps any coins picked up before the save finished loading
    lastMeters ??= saved.lastMeters;
    if (_crashY == null && saved.crashY != null && saved.crashX != null) {
      _crashY = saved.crashY;
      _crashX = saved.crashX;
    }
    owned.addAll(saved.owned.where(Shop.exists));
    final skin = saved.skin, trail = saved.trail;
    if (skin != null && owns(Shop.skin(skin))) skinId = Shop.skin(skin).id;
    if (trail != null && owns(Shop.trail(trail))) trailStyleId = Shop.trail(trail).id;
    memories.addAll(saved.memories.where(Memories.exists));
  }

  // ---------- memories ----------

  /// Brings back [memory] if it was forgotten: shows it (in a versus match it just goes in
  /// the book), and reports it for saving.
  void _remember(Memory memory) {
    if (!memories.add(memory.id)) return;
    newMemories = true;
    onSave?.call(progress);
    if (versus) {
      _showToast('A MEMORY. READ IT IN THE BOOK.');
      _sound(Sfx.memory);
    } else if (shownMemory != null) {
      _waitingMemories.add(memory); // one at a time, so each can be read to the end
    } else {
      _show(memory);
    }
  }

  void _show(Memory memory) {
    shownMemory = memory;
    memoryAge = 0;
    memoryOutro = -1;
    _sound(Sfx.memory);
    if (readingMemory) {
      holding = false; // the bunny waits where it is
      if (memory.arrival) realmCardTime = 0; // the memory names the realm itself
    }
  }

  /// The run is paused on a memory, waiting for the player to read it and continue.
  bool get readingMemory => pauseForMemories && !versus && shownMemory != null && mode == GameMode.playing;

  /// How long the memory's words take to type themselves out.
  double get memoryTypingSeconds => shownMemory == null ? 0 : 0.8 + shownMemory!.text.length / 30;
  bool get memoryTyped => memoryAge >= memoryTypingSeconds;

  /// The player pressed to continue: the first press finishes the words, the next moves on to
  /// the next memory waiting, or closes the memory and goes back to the run. Presses in the
  /// first moment are ignored, so a press that was already happening doesn't skip the memory.
  void continueMemory() {
    if (!readingMemory || memoryAge < 0.5 || memoryOutro >= 0) return;
    if (!memoryTyped) {
      memoryAge = memoryTypingSeconds;
    } else if (_waitingMemories.isNotEmpty) {
      _show(_waitingMemories.removeAt(0));
    } else {
      memoryOutro = 0; // the ink draws back first; then the run goes on
    }
  }

  void _nextMemory() {
    if (_waitingMemories.isNotEmpty) {
      _show(_waitingMemories.removeAt(0));
      return;
    }
    final paused = readingMemory;
    shownMemory = null;
    memoryOutro = -1;
    if (paused) {
      grace = math.max(grace, 1.2); // a moment to get going again
      holding = false;
    }
  }

  /// Where realm [r]'s memory fork is: a little after the realm begins (so its "ENTERING"
  /// card comes first), or early in the run for the first realm.
  double _forkWy(int r) => r == 0 ? 25 * unitsPerMeter : realmStart(r) + 15 * unitsPerMeter;

  /// Realm [r]'s memory fork: the tunnel opens wide, with the realm's own memory on one side
  /// and its next forgotten fragment on the other. Taking one loses the other; both can be
  /// left alone. Its walls are the same for everyone; what it holds depends on what this
  /// player has already remembered.
  void _planFork(_Control prev, int r) {
    _forksPlanned.add(r);
    final a = math.max(_forkWy(r), prev.wy + 320);
    const centre = width / 2;
    _queued.addAll([_Control(a, centre, _forkGap), _Control(a + _forkLength, centre, _forkGap)]);
    // the next bonus stretch keeps its distance, so the two don't run together
    _nextZoneWy = math.max(_nextZoneWy, a + _forkLength + 25 * unitsPerMeter);
    for (var i = 0; i < 3; i++) {
      final wy = a + 40 + i * 40;
      pickups.add(Pickup.coin(centre, wy, wy * 0.05));
    }
    final arrival = Memories.arrivalOf(r);
    final realmMemory = memories.contains(arrival.id) ? null : arrival;
    final fragment = Memories.fragmentsOf(r).where((m) => !memories.contains(m.id)).firstOrNull;
    final wy = a + _forkLength * 0.55;
    final group = ++_groupId;
    if (realmMemory != null && fragment != null) {
      final side = _forkRng.nextBool() ? 1.0 : -1.0;
      pickups.add(Pickup.memory(centre + side * _forkSpread, wy, realmMemory, 0, group: group));
      pickups.add(Pickup.memory(centre - side * _forkSpread, wy, fragment, 2, group: group));
    } else if ((realmMemory ?? fragment) case final only?) {
      pickups.add(Pickup.memory(centre, wy, only, 0, group: group));
    }
  }

  // ---------- shop ----------

  bool owns(ShopItem item) => item.price == 0 || owned.contains(item.id);

  bool isWearing(ShopItem item) => switch (item) {
        BunnySkin() => item.id == skinId,
        TrailStyle() => item.id == trailStyleId,
      };

  bool canAfford(ShopItem item) => coins >= item.price;

  /// Spends coins on [item] and puts it on. Returns false (and spends nothing) if it's
  /// already owned or there aren't enough coins.
  bool buy(ShopItem item) {
    if (owns(item) || !canAfford(item)) return false;
    coins -= item.price;
    owned.add(item.id);
    wear(item);
    return true;
  }

  /// Puts on a skin or trail that's owned.
  void wear(ShopItem item) {
    if (!owns(item)) return;
    switch (item) {
      case BunnySkin():
        skinId = item.id;
      case TrailStyle():
        trailStyleId = item.id;
    }
    onSave?.call(progress);
  }

  // ---------- input ----------

  /// Pointer position is in field units. Touch lifts the steering point above the finger.
  void pointerDown(double x, double y, {bool touch = false}) {
    touchUi = touch;
    if (readingMemory) {
      continueMemory();
      return;
    }
    _touchOffset = touch ? 70 : 0;
    holding = true;
    pointerMove(x, y);
    if (!versus && (mode == GameMode.title || canRetry)) _startGame();
  }

  void pointerMove(double x, double y) {
    if (!holding) return;
    _targetX = x.clamp(0.0, width);
    _targetY = (y - _touchOffset).clamp(0.0, height);
  }

  void pointerUp() => holding = false;

  // ---------- versus ----------

  /// Starts a versus run on [seed]: both players fly the same tunnel. A hold that began
  /// during the countdown steers straight away.
  void startVersusRun(int seed) {
    versus = true;
    runSeed = seed;
    _startGame();
  }

  /// The match is over while this bunny is still flying (the other one crashed): the run
  /// stops here, without a crash.
  void endRunForMatch() {
    if (mode != GameMode.playing) return;
    mode = GameMode.dead;
    endedByMatch = true;
    deadTime = 0;
    holding = false;
    _finishRun();
  }

  /// Back to the title screen's calm tunnel: when leaving a match, or (with [versus]) while
  /// counting down to the next race.
  void toTitle({bool versus = false}) {
    this.versus = versus;
    if (!versus) runSeed = null;
    endedByMatch = false;
    mode = GameMode.title;
    distance = 0;
    realm = 0;
    realmCardTime = 0;
    shownMemory = null;
    shield = false;
    marker = null;
    trail.clear();
    _resetWorld();
  }

  // ---------- power-ups ----------

  void applyPowerUp(PowerUp p) {
    switch (p) {
      case PowerUp.shield:
        shield = true;
        _showToast('SHIELD!');
    }
  }

  // ---------- simulation ----------

  void update(double dt) {
    if (!(dt > 0)) return;
    dt = math.min(dt, 0.05);
    final n = (dt * 120).ceil(); // small substeps so fast runs can't skip through a wall
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      _tick(h);
    }
  }

  void _tick(double h) {
    time += h;
    if (readingMemory) {
      memoryAge += h; // everything else waits
      speed = 0;
      if (memoryOutro >= 0) {
        memoryOutro += h;
        if (memoryOutro >= memoryOutroSeconds) _nextMemory();
      }
      return;
    }
    switch (mode) {
      case GameMode.playing:
        _updateEffects(h);
        runTime += h * levelFactor; // the speed ramp pauses while the level is slowed
        speed = baseSpeed * levelFactor;
      case GameMode.title:
        speed = 110;
      case GameMode.dead:
        speed *= math.exp(-2.2 * h);
        deadTime += h;
    }
    distance += speed * h;
    _fillWalls();

    if (mode == GameMode.playing && holding) {
      final k = 1 - math.exp(-_follow * h);
      bunnyX = (bunnyX + (_targetX - bunnyX) * k).clamp(18.0, width - 18);
      bunnyY = (bunnyY + (_targetY - bunnyY) * k).clamp(80.0, height - 40);
    } else if (mode == GameMode.title) {
      final k = 1 - math.exp(-3 * h);
      bunnyX += (width / 2 - bunnyX) * k;
      bunnyY += (height * 0.7 - bunnyY) * k;
    }

    _updateTrail();
    _updatePickups(h);
    _updateHollows(h);

    final m = marker;
    if (m != null) {
      if (mode == GameMode.playing && !m.passed && worldY(bunnyY) > m.wy) {
        m.passed = true;
        _burst(m.x, m.wy, 30, Palette.ghostSpark, 60, 300);
        _sound(Sfx.ghost);
      }
      if (m.passed) m.fade = math.max(0.0, m.fade - h * 1.4);
    }

    if (mode == GameMode.playing) {
      final flown = (distance / unitsPerMeter).floor();
      if (flown != meters) {
        meters = flown;
        _onNewMeter(flown);
      }
      if (realm + 1 < realms.length && distance >= realmStart(realm + 1)) {
        realm++;
        realmCardTime = realmCardSeconds;
        _sound(Sfx.realm);
      }
      if (grace > 0) {
        grace -= h;
      } else if (_hitsWall()) {
        if (!_survive()) {
          _die();
          return;
        }
      } else if (_touchedHollow() case final hollow?) {
        if (!_survive(hollow: hollow)) {
          _die(spooked: true);
          return;
        }
      }
    }

    shake = math.max(0.0, shake - h * 2.6);
    popTime = math.max(0.0, popTime - h);
    coinPopTime = math.max(0.0, coinPopTime - h);
    toastTime = math.max(0.0, toastTime - h);
    realmCardTime = math.max(0.0, realmCardTime - h);
    if (shownMemory != null) {
      memoryAge += h;
      if (memoryAge >= memorySeconds) _nextMemory(); // not pausing: it shows for a while, then goes
    }
  }

  void _updateEffects(double h) {
    if (_hitTime >= 0) {
      _hitTime += h;
      if (_hitTime >= tuning.shieldHitSlowSeconds + tuning.shieldRecoverSeconds) _hitTime = -1;
    }
  }

  /// A hit that the shield (or the phoenix trail's second chance) can soak up. Returns false
  /// if nothing could, and the run ends.
  bool _survive({Hollow? hollow}) {
    if (shield) {
      shield = false;
      _absorbHit(hollow: hollow, message: 'SHIELD SAVED YOU!');
      return true;
    }
    if (spareLife) {
      spareLife = false;
      _absorbHit(hollow: hollow, message: 'SECOND CHANCE!');
      return true;
    }
    return false;
  }

  /// The hit is soaked up: the bunny gets a moment to steer clear, and the level slows down
  /// before catching back up. A wall puts the bunny back inside the gap; a hollow pops.
  void _absorbHit({Hollow? hollow, required String message}) {
    _hitTime = 0;
    grace = 1.2;
    shake = 0.5;
    if (hollow == null) {
      final (l, r) = wallAt(worldY(bunnyY));
      bunnyX = r - l > 40 ? bunnyX.clamp(l + 20, r - 20) : (l + r) / 2;
      _burst(bunnyX, worldY(bunnyY), 26, const [Palette.shield, Palette.text], 60, 260);
      _sound(Sfx.bump);
    } else {
      hollows.remove(hollow);
      _burst(hollow.x, hollow.wy, 30, const [Palette.hollow, Palette.hollowRim, Palette.shield], 60, 300);
      _sound(Sfx.hollowPop);
    }
    _showToast(message);
    onBump?.call();
  }

  /// Hollows hop with the level's clock, so a slowed level slows them too, and stay clear of
  /// the walls. Ones that have scrolled away are dropped.
  void _updateHollows(double h) {
    _hollowClock += h * (mode == GameMode.playing ? levelFactor : 1);
    for (var i = hollows.length - 1; i >= 0; i--) {
      final g = hollows[i];
      if (screenY(g.wy) > height + 40) {
        hollows.removeAt(i);
        continue;
      }
      // six spots around a sway; it waits at each, crouches, then leaps to the next
      const spots = 6;
      final u = (g.phase + g.rate * _hollowClock) / (2 * math.pi / spots);
      final spot = u.floorToDouble(), f = u - spot;
      final leap = ramp01((f - 0.65) / 0.35);
      final x = g.centre + g.reach * math.sin((spot + leap) * 2 * math.pi / spots);
      g.crouch = ramp01((f - 0.4) / 0.25) * (1 - leap);
      g.hop = math.sin(math.pi * leap);
      final next = g.centre + g.reach * math.sin((spot + 1) * 2 * math.pi / spots);
      if ((next - g.x).abs() > 0.5) g.facing = next > g.x ? 1 : -1;
      final (l, r) = wallAt(g.wy);
      final lo = l + Hollow.radius + 4, hi = r - Hollow.radius - 4;
      g.x = lo < hi ? x.clamp(lo, hi) : (l + r) / 2;
    }
  }

  /// The hollow the bunny's head or body is touching, if any. The phantom skin is never caught.
  Hollow? _touchedHollow() {
    if (hasPerk(Perk.hollowProof)) return null;
    for (final g in hollows) {
      final gy = screenY(g.wy);
      if ((gy - bunnyY).abs() > 60) continue;
      for (final (offset, radius) in _bunnyParts) {
        final dx = g.x - bunnyX, dy = gy - (bunnyY + offset);
        final reach = radius + Hollow.hitRadius;
        if (dx * dx + dy * dy < reach * reach) return g;
      }
    }
    return null;
  }

  /// The trail records where the bunny has been. Nothing is trimmed when it dives: the path
  /// simply turns back down, and old points are dropped only once they scroll off the bottom.
  void _updateTrail() {
    if (mode != GameMode.dead) {
      final tw = tailWorldY;
      final last = trail.isEmpty ? null : trail.last;
      if (last == null || _length(last.x - bunnyX, last.wy - tw) >= 3) {
        trail.add(TrailPoint(bunnyX, tw, _trailId++));
      }
    }
    final bottom = distance - 40;
    var drop = 0;
    while (drop + 2 < trail.length && trail[drop].wy < bottom && trail[drop + 1].wy < bottom) {
      drop++;
    }
    drop = math.max(drop, trail.length - _maxTrail);
    if (drop > 0) trail.removeRange(0, drop);
  }

  void _updatePickups(double h) {
    final bunnyCentre = bunnyY + 2;
    final magnet = mode == GameMode.playing && hasPerk(Perk.magnet);
    final pull = 1 - math.exp(-9 * h);
    final taken = <Pickup>[];
    for (final p in pickups) {
      if (taken.contains(p)) continue; // lost with the choice taken just now
      var sy = screenY(p.wy);
      if (sy > height + 40) {
        taken.add(p); // scrolled away
        continue;
      }
      if (mode != GameMode.playing) continue;
      if (magnet && p.isCoin) {
        final dx = bunnyX - p.x, dy = bunnyCentre - sy;
        if (dx * dx + dy * dy < _magnetReach * _magnetReach) {
          p.x += dx * pull;
          p.wy -= dy * pull; // world y grows upward
          sy = screenY(p.wy);
        }
      }
      final reach = p.isCoin ? 22.0 : 26.0;
      final dx = p.x - bunnyX, dy = sy - bunnyCentre;
      if (dx * dx + dy * dy > reach * reach) continue;
      taken.add(p);
      _take(p, taken);
    }
    pickups.removeWhere(taken.contains);
  }

  void _take(Pickup p, List<Pickup> taken) {
    final power = p.powerUp, memory = p.memory;
    if (memory != null) {
      _burst(p.x, p.wy, 24, const [Palette.glimmer, Palette.moon, Palette.runeViolet], 50, 230);
      // a choice: the ones not taken fade away
      for (final other in pickups) {
        if (other != p && other.group != null && other.group == p.group) {
          taken.add(other);
          _burst(other.x, other.wy, 12, const [Palette.muted, Palette.panelEdge], 30, 120);
        }
      }
      _remember(memory);
    } else if (power == null) {
      final value = hasPerk(Perk.doubleCoins) ? 2 : 1;
      coins += value;
      runCoins += value;
      coinPopTime = 0.2;
      _burst(p.x, p.wy, 6, const [Palette.coin, Palette.text], 40, 160);
      _coinStep = time - _lastCoinTime < _coinRunGap ? math.min(_coinStep + 1, coinSteps - 1) : 0;
      _lastCoinTime = time;
      _sound(Sfx.coin, _coinStep);
      onSave?.call(progress);
    } else {
      applyPowerUp(power);
      _burst(p.x, p.wy, 16, [Palette.powerUp(power), Palette.text], 60, 240);
      _sound(switch (power) {
        PowerUp.shield => Sfx.shield,
      });
    }
  }

  void _startGame() {
    final seed = runSeed;
    if (seed != null) {
      _rng = math.Random(seed);
      _forkRng = math.Random(seed + 7919);
    }
    mode = GameMode.playing;
    endedByMatch = false;
    // the comet skin skips the slow start: the run begins at half again the starting speed
    runTime = hasPerk(Perk.headStart) ? _secondsToSpeed(_baseSpeed * _headStartFactor) : 0;
    distance = 0;
    speed = baseSpeed;
    meters = 0;
    runCoins = 0;
    grace = 1.0;
    bunnyX = width / 2;
    bunnyY = height * 0.72;
    trail.clear();
    bursts.clear();
    shake = 0;
    toastTime = 0;
    newBest = false;
    spooked = false;
    _warnedHollows = false;
    realm = 0;
    realmCardTime = 0;
    shownMemory = null;
    memoryAge = 0;
    _waitingMemories.clear(); // still remembered, just not shown again
    shield = hasPerk(Perk.startShield);
    spareLife = hasPerk(Perk.secondChance);
    _hitTime = -1;
    _hollowClock = 0;
    _coinStep = 0;
    _lastCoinTime = -1;
    _sound(Sfx.takeoff);
    final cy = _crashY, cx = _crashX;
    marker = !versus && cy != null && cx != null ? CrashMarker(cy, cx) : null;
    _resetWorld();
  }

  void _die({bool spooked = false}) {
    mode = GameMode.dead;
    this.spooked = spooked;
    deadTime = 0;
    shake = 1;
    _crashY = worldY(bunnyY);
    _crashX = bunnyX;
    _burst(bunnyX, _crashY!, 70, trailStyle.stripes, 60, 520);
    _sound(Sfx.crash);
    _finishRun();
    onCrash?.call();
  }

  void _finishRun() {
    lastMeters = meters;
    newBest = meters > best;
    if (newBest) best = meters;
    onSave?.call(progress);
  }

  void _onNewMeter(int m) {
    final every = tuning.milestoneEveryMeters;
    if (best > 0 && m == best + 1) {
      _showToast('NEW BEST!');
      _sound(Sfx.newBest);
    } else if (every > 0 && m > 0 && m % every == 0) {
      _showToast('$m METERS!');
      _sound(Sfx.milestone);
    } else {
      return;
    }
    popTime = 0.25;
    _burst(width / 2, worldY(height * 0.3), 36, Palette.sprinkles, 80, 380);
  }

  void _showToast(String text) {
    toast = text;
    toastTime = 1.6;
  }

  void _sound(Sfx sfx, [int step = 0]) {
    sounds.add(SoundCue(sfx, step));
    if (sounds.length > _maxSounds) sounds.removeAt(0); // nobody is draining (e.g. in tests)
  }

  void _burst(double x, double wy, int count, List<Color> colors, double minSpeed, double maxSpeed) {
    bursts.add(Burst(x, wy, count, colors, minSpeed, maxSpeed));
    if (bursts.length > _maxBursts) bursts.removeAt(0); // nobody is draining (e.g. in tests)
  }

  // ---------- tunnel ----------
  // Control points hold a centre line and a gap width; Catmull-Rom curves join them. Every
  // decision depends only on the dice and the world height, so the same seed makes the same
  // tunnel.

  /// How hard the tunnel is at world height [wy]: 0 at the bottom, 1 from
  /// [GameTuning.hardestAtMeters].
  double _difficultyAt(double wy) => (wy / unitsPerMeter / tuning.hardestAtMeters).clamp(0.0, 1.0);

  /// Chance that a stretch of open space at world height [wy] gets a hollow: none before
  /// [GameTuning.hollowsFromRealm], then growing to [GameTuning.hollowChance].
  double _hollowChanceAt(double wy) {
    final from = tuning.hollowsFromRealm, common = tuning.hollowsCommonAtRealm;
    final r = _realmProgress(wy);
    if (tuning.hollowChance <= 0 || r < from) return 0;
    final t = common > from ? ((r - from) / (common - from)).clamp(0.0, 1.0) : 1.0;
    return tuning.hollowChance * _lerp(0.5, 1, t);
  }

  _Control _makeControl(_Control prev) {
    if (_queued.isNotEmpty) return _queued.removeAt(0);
    if (mode == GameMode.title) {
      return _Control(prev.wy + _rand(300, 420), width / 2 + _rand(-36, 36), _rand(285, 330));
    }
    for (var r = 0; r < realms.length; r++) {
      if (!_forksPlanned.contains(r) && prev.wy + 450 >= _forkWy(r)) {
        _planFork(prev, r);
        return _queued.removeAt(0);
      }
    }
    if (prev.wy + 450 >= _nextZoneWy && !_forkDueBefore(_nextZoneWy + 45 * unitsPerMeter)) {
      _planBonusZone(prev);
      return _queued.removeAt(0);
    }
    final openChance = _hollowChanceAt(prev.wy) > 0 ? tuning.openSectionChanceLate : tuning.openSectionChance;
    if (_rng.nextDouble() < openChance) {
      _planOpenSection(prev);
      return _queued.removeAt(0);
    }

    final d = _difficultyAt(prev.wy);
    final gMin = _lerp(170, 104, d), gMax = _lerp(290, 210, d);
    final gap = _rng.nextDouble() < _lerp(0.25, 0.45, d) ? gMin + _rand(0, 14) : _rand(gMin, gMax);
    final shift = _lerp(110, 175, d);
    final lo = gap / 2 + 14, hi = width - gap / 2 - 14;
    // wander toward a random spot, but never further than `shift` in one stretch
    final centre = (prev.centre + (_rand(lo, hi) - prev.centre).clamp(-shift, shift)).clamp(lo, hi);
    final control = _Control(prev.wy + _rand(260, 420) * _stretchAt(prev.wy), centre, gap);
    if (_rng.nextDouble() < tuning.powerUpChance) {
      pickups.add(Pickup.powerUp(centre, control.wy, _randomPowerUp(), _rand(0, 6)));
    }
    return control;
  }

  /// A memory fork is still to come below world height [wy]. A bonus stretch waits for it.
  bool _forkDueBefore(double wy) {
    for (var r = 0; r < realms.length; r++) {
      if (!_forksPlanned.contains(r) && _forkWy(r) < wy) return true;
    }
    return false;
  }

  /// Faster flight stretches the tunnel's bends out so they stay steerable.
  double _stretchAt(double wy) =>
      1 + 0.65 * ((expectedSpeedAt(wy) - _baseSpeed) / (_maxSpeed - _baseSpeed)).clamp(0.0, 1.0);

  /// A long wide-open stretch with a snake of coins and one power-up.
  void _planBonusZone(_Control prev) {
    final start = math.max(_nextZoneWy, prev.wy + 300);
    final length = math.max(900.0, expectedSpeedAt(start) * tuning.bonusZoneSeconds);
    _queued.addAll([
      _Control(start, width / 2, _wideGap),
      _Control(start + length / 2, width / 2, _wideGap),
      _Control(start + length, width / 2, _wideGap),
    ]);
    for (var wy = start + 60; wy < start + length - 60; wy += 42) {
      final t = (wy - start) / length;
      pickups.add(Pickup.coin(width / 2 + math.sin(t * math.pi * 3) * 115, wy, wy * 0.05));
    }
    pickups.add(Pickup.powerUp(width / 2 - 115 * math.sin(math.pi * 1.5), start + length / 2, _randomPowerUp(), 0));
    final every = tuning.bonusZoneEveryMeters * unitsPerMeter;
    while (_nextZoneWy < start + length + 2 * unitsPerMeter) {
      _nextZoneWy += every;
    }
  }

  /// A shorter wide spot in the ordinary tunnel, with a few coins down the middle. Once the
  /// Hollow Ones are about, this open space is where they wait: one, or late on sometimes two
  /// at different heights.
  void _planOpenSection(_Control prev) {
    final gap = _rand(290, 340);
    final centre = width / 2 + _rand(-15, 15);
    final stretch = _stretchAt(prev.wy);
    final a = prev.wy + _rand(300, 420) * stretch;
    final b = a + _rand(260, 380) * stretch;
    _queued.addAll([_Control(a, centre, gap), _Control(b, centre, gap)]);
    for (var i = 0; i < 6; i++) {
      final wy = a + (b - a) * (i + 0.5) / 6;
      pickups.add(Pickup.coin(centre + math.sin(i * 0.9) * 40, wy, wy * 0.05));
    }
    final chance = _hollowChanceAt(a);
    if (chance > 0 && _rng.nextDouble() < chance) {
      final two = _rng.nextDouble() < chance * 0.5;
      if (two) {
        _addHollow(a + (b - a) / 3, centre, gap);
        _addHollow(a + 2 * (b - a) / 3, centre, gap);
      } else {
        _addHollow((a + b) / 2, centre, gap);
      }
    }
  }

  /// A hollow hopping across a stretch [gap] wide. However far it hops, the other side keeps
  /// at least [_passage] free.
  void _addHollow(double wy, double centre, double gap) {
    if (gap < _hollowMinGap) return;
    final reach = (gap / 2 - Hollow.radius - 6) * _rand(0.45, 1);
    final rate = math.min(_lerp(0.9, 1.8, _difficultyAt(wy)) * _rand(0.8, 1.2), _maxHollowDrift / reach);
    hollows.add(Hollow(wy, centre, reach, rate, _rand(0, 2 * math.pi)));
    if (!_warnedHollows) {
      _warnedHollows = true;
      _showToast('THEY FOUND YOU.');
    }
  }

  PowerUp _randomPowerUp() => PowerUp.shield;

  void _ensureControls(int n) {
    while (_controls.length <= n) {
      _controls.add(_makeControl(_controls.last));
    }
  }

  WallSample _sampleWall(double wy) {
    _ensureControls(_ctrlIdx + 2);
    while (_controls[_ctrlIdx + 1].wy <= wy) {
      _ctrlIdx++;
      _ensureControls(_ctrlIdx + 2);
    }
    if (_ctrlIdx > 6) {
      _controls.removeRange(0, _ctrlIdx - 2);
      _ctrlIdx = 2;
    }
    final p0 = _controls[math.max(0, _ctrlIdx - 1)];
    final p1 = _controls[_ctrlIdx];
    final p2 = _controls[_ctrlIdx + 1];
    final p3 = _controls[_ctrlIdx + 2];
    final t = (wy - p1.wy) / (p2.wy - p1.wy);
    var centre = _catmull(p0.centre, p1.centre, p2.centre, p3.centre, t);
    final gap = math.max(96.0, _catmull(p0.gap, p1.gap, p2.gap, p3.gap, t));
    centre += math.sin(wy * 0.021 + _wobble) * 4 * (0.5 + _difficultyAt(wy));
    var l = centre - gap / 2, r = centre + gap / 2;
    if (l < 10) {
      r += 10 - l;
      l = 10;
    }
    if (r > width - 10) {
      l -= r - (width - 10);
      r = width - 10;
    }
    return WallSample(wy, math.max(10.0, l), r, _sampleId++);
  }

  void _fillWalls() {
    final need = distance + height + 80;
    while (_nextW <= need) {
      walls.add(_sampleWall(_nextW));
      _nextW += _step;
    }
    var drop = 0;
    while (walls.length - drop > 3 && walls[drop + 1].wy < distance - 60) {
      drop++;
    }
    if (drop > 0) walls.removeRange(0, drop);
  }

  void _resetWorld() {
    _controls
      ..clear()
      ..addAll(const [
        _Control(-700, width / 2, width - 40),
        _Control(-300, width / 2, width - 40),
        _Control(defaultHeight * 0.95, width / 2, width - 56), // the same opening on any screen
      ]);
    _queued.clear();
    pickups.clear();
    hollows.clear();
    _forksPlanned.clear();
    _ctrlIdx = 0;
    _nextZoneWy =
        tuning.bonusZoneEveryMeters > 0 ? tuning.bonusZoneEveryMeters * unitsPerMeter : double.infinity;
    walls.clear();
    _sampleId = 0;
    _nextW = distance - 120;
    _wobble = _rand(0, 2 * math.pi);
    _fillWalls();
  }

  /// Left and right wall x at world height [wy].
  (double, double) wallAt(double wy) {
    final first = walls.first;
    final f = (wy - first.wy) / _step;
    final i = f.floor();
    if (i < 0) return (first.left, first.right);
    if (i >= walls.length - 1) return (walls.last.left, walls.last.right);
    final t = f - i;
    final a = walls[i], b = walls[i + 1];
    return (a.left + (b.left - a.left) * t, a.right + (b.right - a.right) * t);
  }

  /// The bunny's head and body as circles: (offset below the bunny's y, radius). The ears are
  /// left out on purpose.
  static const _bunnyParts = [(-2.5 * bunnyPixel, 7.0 * bunnyPixel), (5.5 * bunnyPixel, 6.2 * bunnyPixel)];

  bool _hitsWall() {
    const steps = [-1.0, -0.7, -0.35, 0.0, 0.35, 0.7, 1.0];
    for (final (offset, radius) in _bunnyParts) {
      final cy = bunnyY + offset;
      for (final f in steps) {
        final halfChord = radius * math.sqrt(math.max(0.0, 1 - f * f));
        final (l, r) = wallAt(worldY(cy + f * radius));
        if (bunnyX - halfChord < l || bunnyX + halfChord > r) return true;
      }
    }
    return false;
  }

  // ---------- helpers ----------

  double _rand(double a, double b) => a + _rng.nextDouble() * (b - a);

  /// Smooth 0-to-1 ease of [t], which is clamped first.
  static double ramp01(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static double _length(double x, double y) => math.sqrt(x * x + y * y);
  static double _catmull(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t, t3 = t2 * t;
    return 0.5 *
        (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}
