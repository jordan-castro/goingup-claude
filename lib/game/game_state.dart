import 'dart:math' as math;
import 'dart:ui' show Color;

import 'palette.dart';
import 'tuning.dart';

export 'tuning.dart';

/// Which screen the game is showing.
enum GameMode { title, playing, dead }

/// Collectible power-ups. Boost, slow and freeze are timed; the shield waits for a hit.
enum PowerUp { boost, slow, freeze, shield }

/// What survives between sessions.
class SavedProgress {
  const SavedProgress({this.best = 0, this.coins = 0, this.lastScreens, this.crashY, this.crashX});

  /// Most screens flown in one run.
  final int best;

  /// All coins ever collected.
  final int coins;

  /// Screens flown in the last run, and where (world height and x) it ended.
  final int? lastScreens;
  final double? crashY;
  final double? crashX;
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

/// A coin or power-up floating in the tunnel, in world coordinates.
class Pickup {
  const Pickup.coin(this.x, this.wy, this.phase) : powerUp = null;
  const Pickup.powerUp(this.x, this.wy, PowerUp this.powerUp, this.phase);

  final double x, wy, phase;
  final PowerUp? powerUp;

  bool get isCoin => powerUp == null;
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
/// World y grows upward and [distance] is how far the field has scrolled.
class GameState {
  GameState({int? seed, this.tuning = const GameTuning(), this.onSave, this.onCrash, this.onBump})
      : _rng = math.Random(seed) {
    _resetWorld();
  }

  static const double width = 400;
  static const double minHeight = 640, maxHeight = 870;
  static const double screenLength = 720; // distance that counts as one "screen"
  static const double bunnyPixel = 2.2; // size of one bunny sprite pixel
  static const double trailStripe = 4.4;
  static const double trailWidth = trailStripe * 6;
  static const double trailTailOffset = 8 * bunnyPixel; // trail leaves from the bunny's feet
  static const double overDelay = 0.45, retryDelay = 0.95;

  static const double _baseSpeed = 190, _maxSpeed = 1250;
  static const double _follow = 15; // how snappily the bunny chases the pointer
  static const double _step = 8; // spacing of wall samples
  static const double _wideGap = width - 40;
  static const int _maxTrail = 900;
  static const int _maxBursts = 40;

  final GameTuning tuning;
  final math.Random _rng;

  /// Called when something worth saving changes (a crash, a coin). Callers may batch writes.
  void Function(SavedProgress progress)? onSave;
  void Function()? onCrash;

  /// Called when the shield takes a hit.
  void Function()? onBump;

  GameMode mode = GameMode.title;
  double time = 0, runTime = 0, distance = 0, speed = 110;
  int screens = 0, best = 0;
  bool newBest = false;
  int? lastScreens;

  /// All coins ever collected, and the ones from this run.
  int coins = 0, runCoins = 0;

  /// The timed power-up in effect (boost, slow or freeze), and the seconds it has left.
  PowerUp? effect;
  double effectTime = 0, effectDuration = 0;
  bool shield = false;

  /// Show touch wording ("touch and hold") instead of mouse wording.
  bool touchUi = false;

  double bunnyX = width / 2, bunnyY = screenLength * 0.7;
  double _targetX = width / 2, _targetY = screenLength * 0.7;
  bool holding = false;
  double _touchOffset = 0;
  double grace = 0, deadTime = 0, shake = 0, popTime = 0, coinPopTime = 0;
  String toast = '';
  double toastTime = 0;

  double _effectFactor = 1; // eases toward the active power-up's speed
  double _hitTime = -1; // seconds since the shield took a hit, or -1

  final List<_Control> _controls = [];
  final List<_Control> _queued = []; // planned stretches (bonus zones, open sections)
  int _ctrlIdx = 0;
  double _nextZoneWy = double.infinity;
  final List<WallSample> walls = [];
  int _sampleId = 0;
  double _nextW = 0, _wobble = 0;

  final List<TrailPoint> trail = [];
  int _trailId = 0;
  final List<Pickup> pickups = [];

  /// Particle puffs waiting for the view to show them. The view empties this list.
  final List<Burst> bursts = [];

  double? _crashY, _crashX;
  CrashMarker? marker;

  double _height = screenLength;
  double get height => _height;
  set height(double value) => _height = value.clamp(minHeight, maxHeight);

  bool get showGameOver => mode == GameMode.dead && deadTime >= overDelay;
  bool get canRetry => mode == GameMode.dead && deadTime > retryDelay;

  /// Field y (0 at the top of the screen) of world height [wy].
  double screenY(double wy) => height - (wy - distance);

  /// World height of field y [y].
  double worldY(double y) => distance + height - y;

  double get tailWorldY => worldY(bunnyY + trailTailOffset);

  /// How far the run has sunk into darkness: 0 is the bright start (and the title screen),
  /// 1 is full night at [GameTuning.darkestAtScreen]. Keeps its value through the game-over
  /// screen and drops back to 0 when a new run starts.
  double get mood {
    if (mode == GameMode.title) return 0;
    return (distance / (screenLength * tuning.darkestAtScreen)).clamp(0.0, 1.0);
  }

  /// Level speed before power-ups: slow at first, then faster.
  double get baseSpeed => math.min(_maxSpeed, _baseSpeed + 4 * runTime + 0.075 * runTime * runTime);

  /// How much power-ups and shield hits are scaling the level speed right now.
  double get levelFactor => _effectFactor * _hitFactor;

  double get _hitFactor {
    if (_hitTime < 0) return 1;
    final slow = tuning.shieldHitSlowSeconds;
    if (_hitTime < slow) return tuning.shieldHitSlowFactor;
    final t = (_hitTime - slow) / tuning.shieldRecoverSeconds;
    return t >= 1 ? 1 : _lerp(tuning.shieldHitSlowFactor, 1, t);
  }

  double get _targetEffectFactor => switch (effect) {
        PowerUp.boost => tuning.boostFactor,
        PowerUp.slow => tuning.slowFactor,
        PowerUp.freeze => 0.0,
        _ => 1.0,
      };

  SavedProgress get progress =>
      SavedProgress(best: best, coins: coins, lastScreens: lastScreens, crashY: _crashY, crashX: _crashX);

  void restore(SavedProgress saved) {
    best = math.max(best, saved.best);
    coins += saved.coins; // keeps any coins picked up before the save finished loading
    lastScreens ??= saved.lastScreens;
    if (_crashY == null && saved.crashY != null && saved.crashX != null) {
      _crashY = saved.crashY;
      _crashX = saved.crashX;
    }
  }

  // ---------- input ----------

  /// Pointer position is in field units. Touch lifts the steering point above the finger.
  void pointerDown(double x, double y, {bool touch = false}) {
    touchUi = touch;
    _touchOffset = touch ? 70 : 0;
    holding = true;
    pointerMove(x, y);
    if (mode == GameMode.title || canRetry) _startGame();
  }

  void pointerMove(double x, double y) {
    if (!holding) return;
    _targetX = x.clamp(0.0, width);
    _targetY = (y - _touchOffset).clamp(0.0, height);
  }

  void pointerUp() => holding = false;

  // ---------- power-ups ----------

  void applyPowerUp(PowerUp p) {
    switch (p) {
      case PowerUp.shield:
        shield = true;
        _showToast('SHIELD!');
      case PowerUp.boost:
        _startEffect(p, tuning.boostSeconds, 'BOOST!');
      case PowerUp.slow:
        _startEffect(p, tuning.slowSeconds, 'SLOW DOWN');
      case PowerUp.freeze:
        _startEffect(p, tuning.freezeSeconds, 'FREEZE!');
    }
  }

  void _startEffect(PowerUp p, double seconds, String label) {
    effect = p;
    effectTime = effectDuration = seconds;
    _showToast(label);
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
    switch (mode) {
      case GameMode.playing:
        _updateEffects(h);
        runTime += h * levelFactor; // the speed ramp pauses while the level is frozen
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
    _updatePickups();

    final m = marker;
    if (m != null) {
      if (mode == GameMode.playing && !m.passed && worldY(bunnyY) > m.wy) {
        m.passed = true;
        _burst(m.x, m.wy, 30, Palette.ghostSpark, 60, 300);
      }
      if (m.passed) m.fade = math.max(0.0, m.fade - h * 1.4);
    }

    if (mode == GameMode.playing) {
      final s = (distance / screenLength).floor();
      if (s != screens) {
        screens = s;
        _onNewScreen(s);
      }
      if (grace > 0) {
        grace -= h;
      } else if (_hitsWall()) {
        if (shield) {
          _absorbHit();
        } else {
          _die();
          return;
        }
      }
    }

    shake = math.max(0.0, shake - h * 2.6);
    popTime = math.max(0.0, popTime - h);
    coinPopTime = math.max(0.0, coinPopTime - h);
    toastTime = math.max(0.0, toastTime - h);
  }

  void _updateEffects(double h) {
    if (effect != null) {
      effectTime -= h;
      if (effectTime <= 0) effect = null;
    }
    _effectFactor += (_targetEffectFactor - _effectFactor) * (1 - math.exp(-8 * h));
    if (_hitTime >= 0) {
      _hitTime += h;
      if (_hitTime >= tuning.shieldHitSlowSeconds + tuning.shieldRecoverSeconds) _hitTime = -1;
    }
  }

  /// The shield soaks up the hit: the bunny is put back inside the gap, gets a moment to
  /// steer clear, and the level slows down before catching back up.
  void _absorbHit() {
    shield = false;
    _hitTime = 0;
    grace = 1.2;
    shake = 0.5;
    final (l, r) = wallAt(worldY(bunnyY));
    bunnyX = r - l > 40 ? bunnyX.clamp(l + 20, r - 20) : (l + r) / 2;
    _burst(bunnyX, worldY(bunnyY), 26, const [Palette.shield, Palette.text], 60, 260);
    _showToast('SHIELD SAVED YOU!');
    onBump?.call();
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

  void _updatePickups() {
    final bunnyCentre = bunnyY + 2;
    for (var i = pickups.length - 1; i >= 0; i--) {
      final p = pickups[i];
      final sy = screenY(p.wy);
      if (sy > height + 40) {
        pickups.removeAt(i);
        continue;
      }
      if (mode != GameMode.playing) continue;
      final reach = p.isCoin ? 22.0 : 26.0;
      final dx = p.x - bunnyX, dy = sy - bunnyCentre;
      if (dx * dx + dy * dy > reach * reach) continue;
      pickups.removeAt(i);
      final power = p.powerUp;
      if (power == null) {
        coins++;
        runCoins++;
        coinPopTime = 0.2;
        _burst(p.x, p.wy, 6, const [Palette.coin, Palette.text], 40, 160);
        onSave?.call(progress);
      } else {
        applyPowerUp(power);
        _burst(p.x, p.wy, 16, [Palette.powerUp(power), Palette.text], 60, 240);
      }
    }
  }

  void _startGame() {
    mode = GameMode.playing;
    runTime = 0;
    distance = 0;
    speed = _baseSpeed;
    screens = 0;
    runCoins = 0;
    grace = 1.0;
    bunnyX = width / 2;
    bunnyY = height * 0.72;
    trail.clear();
    bursts.clear();
    shake = 0;
    toastTime = 0;
    newBest = false;
    effect = null;
    shield = false;
    _effectFactor = 1;
    _hitTime = -1;
    final cy = _crashY, cx = _crashX;
    marker = cy != null && cx != null ? CrashMarker(cy, cx) : null;
    _resetWorld();
  }

  void _die() {
    mode = GameMode.dead;
    deadTime = 0;
    shake = 1;
    effect = null;
    _crashY = worldY(bunnyY);
    _crashX = bunnyX;
    _burst(bunnyX, _crashY!, 70, Palette.rainbow, 60, 520);
    lastScreens = screens;
    newBest = screens > best;
    if (newBest) best = screens;
    onSave?.call(progress);
    onCrash?.call();
  }

  void _onNewScreen(int s) {
    popTime = 0.25;
    if (best > 0 && s == best + 1) {
      _showToast('NEW BEST!');
    } else if (s > 0 && s % 10 == 0) {
      _showToast('$s SCREENS!');
    } else {
      return;
    }
    _burst(width / 2, worldY(height * 0.3), 36, Palette.sprinkles, 80, 380);
  }

  void _showToast(String text) {
    toast = text;
    toastTime = 1.6;
  }

  void _burst(double x, double wy, int count, List<Color> colors, double minSpeed, double maxSpeed) {
    bursts.add(Burst(x, wy, count, colors, minSpeed, maxSpeed));
    if (bursts.length > _maxBursts) bursts.removeAt(0); // nobody is draining (e.g. in tests)
  }

  // ---------- tunnel ----------
  // Control points hold a centre line and a gap width; Catmull-Rom curves join them.

  double get _difficulty => math.min(1.0, screens / 40);

  _Control _makeControl(_Control prev) {
    if (_queued.isNotEmpty) return _queued.removeAt(0);
    if (mode == GameMode.title) {
      return _Control(prev.wy + _rand(300, 420), width / 2 + _rand(-36, 36), _rand(285, 330));
    }
    if (prev.wy + 450 >= _nextZoneWy) {
      _planBonusZone(prev);
      return _queued.removeAt(0);
    }
    if (_rng.nextDouble() < tuning.openSectionChance) {
      _planOpenSection(prev);
      return _queued.removeAt(0);
    }

    final d = _difficulty;
    final gMin = _lerp(170, 104, d), gMax = _lerp(290, 210, d);
    final gap = _rng.nextDouble() < _lerp(0.25, 0.45, d) ? gMin + _rand(0, 14) : _rand(gMin, gMax);
    final shift = _lerp(110, 175, d);
    final lo = gap / 2 + 14, hi = width - gap / 2 - 14;
    // wander toward a random spot, but never further than `shift` in one stretch
    final centre = (prev.centre + (_rand(lo, hi) - prev.centre).clamp(-shift, shift)).clamp(lo, hi);
    final control = _Control(prev.wy + _rand(260, 420) * _stretch, centre, gap);
    if (_rng.nextDouble() < tuning.powerUpChance) {
      pickups.add(Pickup.powerUp(centre, control.wy, _randomPowerUp(), _rand(0, 6)));
    }
    return control;
  }

  /// Faster flight stretches the tunnel's bends out so they stay steerable.
  double get _stretch => 1 + 0.65 * ((baseSpeed - _baseSpeed) / (_maxSpeed - _baseSpeed)).clamp(0.0, 1.0);

  /// A long wide-open stretch with a snake of coins and one power-up.
  void _planBonusZone(_Control prev) {
    final start = math.max(_nextZoneWy, prev.wy + 300);
    final length = math.max(900.0, baseSpeed * tuning.bonusZoneSeconds);
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
    final every = tuning.bonusZoneEvery * screenLength;
    while (_nextZoneWy < start + length + screenLength) {
      _nextZoneWy += every;
    }
  }

  /// A shorter wide spot in the ordinary tunnel, with a few coins down the middle.
  void _planOpenSection(_Control prev) {
    final gap = _rand(290, 340);
    final centre = width / 2 + _rand(-15, 15);
    final a = prev.wy + _rand(300, 420) * _stretch;
    final b = a + _rand(260, 380) * _stretch;
    _queued.addAll([_Control(a, centre, gap), _Control(b, centre, gap)]);
    for (var i = 0; i < 6; i++) {
      final wy = a + (b - a) * (i + 0.5) / 6;
      pickups.add(Pickup.coin(centre + math.sin(i * 0.9) * 40, wy, wy * 0.05));
    }
  }

  PowerUp _randomPowerUp() {
    final r = _rng.nextDouble();
    if (r < 0.25) return PowerUp.boost;
    if (r < 0.55) return PowerUp.slow;
    if (r < 0.70) return PowerUp.freeze;
    return PowerUp.shield;
  }

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
    centre += math.sin(wy * 0.021 + _wobble) * 4 * (0.5 + _difficulty);
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
      ])
      ..add(_Control(height * 0.95, width / 2, width - 56));
    _queued.clear();
    pickups.clear();
    _ctrlIdx = 0;
    _nextZoneWy = tuning.bonusZoneEvery > 0 ? tuning.bonusZoneEvery * screenLength : double.infinity;
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

  /// Two circles (head and body) checked against the walls; the ears are left out on purpose.
  bool _hitsWall() {
    const parts = [(-2.5 * bunnyPixel, 7.0 * bunnyPixel), (5.5 * bunnyPixel, 6.2 * bunnyPixel)];
    const steps = [-1.0, -0.7, -0.35, 0.0, 0.35, 0.7, 1.0];
    for (final (offset, radius) in parts) {
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
  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static double _length(double x, double y) => math.sqrt(x * x + y * y);
  static double _catmull(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t, t3 = t2 * t;
    return 0.5 *
        (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}
