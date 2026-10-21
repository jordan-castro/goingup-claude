import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'components/atmosphere.dart';
import 'components/bunny.dart';
import 'components/crash_marker.dart';
import 'components/hollows.dart';
import 'components/hud.dart';
import 'components/pickups.dart';
import 'components/memories_screen.dart';
import 'components/shop_screen.dart';
import 'components/starfield.dart';
import 'components/trail.dart';
import 'components/tunnel.dart';
import 'drawing.dart';
import 'game_state.dart';
import 'music.dart';
import 'palette.dart';
import 'sfx.dart';
import 'sprites.dart';
import 'stages.dart';

/// The Flame side of goingUP: runs [state] every frame and shows (and plays) it.
///
/// World coordinates are (x, -worldY), so up the tunnel is up the screen. The camera's
/// viewport is always [GameState.width] wide with a height that follows the screen's shape
/// (between a 1.6 and 2.175 aspect, letterboxed beyond that), and the viewfinder scrolls with
/// the distance flown.
class GoingUpGame extends FlameGame with DragCallbacks, KeyboardEvents {
  GoingUpGame({GameState? state, GameMusic? music, GameSfx? sfx})
      : state = state ?? GameState(),
        music = music ?? SilentMusic(),
        sfx = sfx ?? SilentSfx();

  final GameState state;
  final GameMusic music;
  final GameSfx sfx;

  /// Mutes (or unmutes) the music and the sound effects together.
  bool get muted => music.muted;
  set muted(bool value) {
    music.muted = value;
    sfx.muted = value;
  }

  /// Called when the player mutes or unmutes, so the choice can be saved.
  void Function(bool muted)? onMuteChanged;

  /// The run's mood (0 bright, 1 dark and mystic), eased so changes are gradual: the picture
  /// and music follow this rather than [GameState.mood] directly.
  double mood = 0;

  /// How far into the Void the picture is, eased the same way from [GameState.deep].
  double deep = 0;

  /// How broken and twisted the scenery looks: shards from twilight, cracks from starfall,
  /// warping from runelight, tearing in the Void. 0 to 1.
  double get corruption => (0.75 * mood + 0.25 * deep).clamp(0.0, 1.0);

  /// How much of each realm's look is showing right now.
  Stages get stages => Stages(mood, deep);

  Sprites? _sprites;
  Sprites get sprites => _sprites!;
  late final List<Component> _overlays; // field-space layers in the viewport, over the world
  final ShopScreen shop = ShopScreen();
  final MemoriesScreen book = MemoriesScreen();
  final _rng = math.Random();
  int? _pointer; // the one pointer that steers; extra fingers are ignored

  /// The picture tearing in the deepest realms: seconds left, and the torn bands as (top and
  /// height as fractions of the screen, sideways shift in field units).
  double _glitch = 0;
  final List<(double, double, double)> _tears = [];

  /// System bars over the game (set by the host widget), turned into field units below.
  EdgeInsets safePadding = EdgeInsets.zero;

  double get safeTop => _safeInset(safePadding.top);
  double get safeBottom => _safeInset(safePadding.bottom);

  double _safeInset(double inset) {
    final viewport = camera.viewport;
    final margin = (canvasSize.y - viewport.size.y) / 2; // letterbox above and below the field
    final scale = viewport.size.y / state.height;
    if (scale <= 0) return 0;
    return math.max(0.0, inset - margin) / scale;
  }

  static double fieldHeightFor(Vector2 canvas) {
    if (canvas.x <= 0 || canvas.y <= 0) return GameState.screenLength;
    final aspect = (canvas.y / canvas.x).clamp(GameState.minHeight / GameState.width, GameState.maxHeight / GameState.width);
    return GameState.width * aspect;
  }

  @override
  Color backgroundColor() => Palette.page;

  @override
  Future<void> onLoad() async {
    _sprites = Sprites();
    state.height = fieldHeightFor(size);
    _overlays = [Atmosphere(), shop, book, Hud()]; // the HUD's speaker button stays on top
    camera = CameraComponent(
      world: world,
      viewport: FixedResolutionViewport(resolution: Vector2(GameState.width, state.height)),
      backdrop: Starfield(),
    );
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewport.addAll(_overlays);
    world.addAll([Trail(), Tunnel(), PickupLayer(), HollowLayer(), CrashMarkerView(), BunnyView()]);
    _followState();
    if (!kIsWeb) _startSound(); // browsers only allow sound after a tap or click
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    final height = fieldHeightFor(size);
    state.height = height;
    final viewport = camera.viewport;
    if (viewport is FixedResolutionViewport && (viewport.resolution.y - height).abs() < 0.5) return;
    // A fixed-resolution viewport can't change shape, so swap in a new one and move the
    // atmosphere and HUD across.
    final next = FixedResolutionViewport(resolution: Vector2(GameState.width, height));
    camera.viewport = next;
    for (final overlay in _overlays) {
      overlay.parent = next;
    }
  }

  @override
  void update(double dt) {
    state.update(dt);
    for (final burst in state.bursts) {
      world.add(_particles(burst));
    }
    state.bursts.clear();
    for (final cue in state.sounds) {
      sfx.play(cue);
    }
    state.sounds.clear();
    final target = state.mood, deepTarget = state.deep;
    final rate = target < mood ? 1.5 : 4.0; // a new run brightens back over a couple of seconds
    mood += (target - mood) * (1 - math.exp(-rate * math.min(dt, 0.1)));
    deep += (deepTarget - deep) * (1 - math.exp(-(deepTarget < deep ? 2.0 : 4.0) * math.min(dt, 0.1)));
    music.update(mood, deep, quiet: state.mode == GameMode.dead || state.readingMemory);
    _glitch = math.max(0.0, _glitch - dt);
    final tearing = state.mode == GameMode.playing ? 0.15 * ramp(corruption, 0.7, 1) + 0.45 * deep : 0.0;
    if (_glitch <= 0 && _rng.nextDouble() < tearing * dt) _tear();
    _followState();
    super.update(dt);
  }

  /// Starts a short glitch: a few bands of the picture slip sideways, with a crackle.
  void _tear() {
    _glitch = 0.08 + _rng.nextDouble() * 0.16;
    _tears
      ..clear()
      ..addAll([
        for (var i = 0, n = 2 + _rng.nextInt(3); i < n; i++)
          (_rng.nextDouble() * 0.95, 0.008 + _rng.nextDouble() * 0.05, (_rng.nextDouble() - 0.5) * 36),
      ]);
    sfx.play(const SoundCue(Sfx.glitch));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_glitch <= 0) return;
    final scale = size.x / GameState.width;
    for (final (top, height, shift) in _tears) {
      final band = Rect.fromLTWH(0, top * size.y, size.x, height * size.y);
      canvas.save();
      canvas.clipRect(band);
      canvas.translate(shift * scale, 0);
      super.render(canvas);
      canvas.restore();
      canvas.drawRect(Rect.fromLTWH(0, band.top, size.x, 1.5), Paint()..color = Palette.hot.withValues(alpha: 0.6));
      canvas.drawRect(Rect.fromLTWH(0, band.bottom - 1.5, size.x, 1.5), Paint()..color = Palette.glimmer.withValues(alpha: 0.5));
    }
  }

  /// Point the camera at the part of the tunnel in view, plus any shake.
  void _followState() {
    final shake = state.shake * 6;
    camera.viewfinder.position = Vector2(
      math.sin(state.time * 91) * shake,
      -(state.distance + state.height) + math.cos(state.time * 77) * shake,
    );
  }

  ParticleSystemComponent _particles(Burst burst) {
    return ParticleSystemComponent(
      position: Vector2(burst.x, -burst.wy),
      priority: 4,
      particle: Particle.generate(
        count: burst.count,
        lifespan: 1.4,
        applyLifespanToChildren: false,
        generator: (i) {
          final angle = _rng.nextDouble() * 2 * math.pi;
          final speed = burst.minSpeed + _rng.nextDouble() * (burst.maxSpeed - burst.minSpeed);
          final life = 0.6 + _rng.nextDouble() * 0.8;
          final size = 2.5 + _rng.nextDouble() * 4;
          final paint = Paint()..color = burst.colors[i % burst.colors.length];
          final start = Vector2(_rng.nextDouble() * 16 - 8, _rng.nextDouble() * 28 - 14);
          return MovingParticle(
            from: start,
            to: start + Vector2(math.cos(angle), math.sin(angle)) * (speed / 2.4), // drifts to a stop
            lifespan: life,
            curve: Curves.easeOutCubic,
            child: ComputedParticle(
              lifespan: life,
              renderer: (canvas, particle) {
                final p = particle.progress;
                paint.color = paint.color.withValues(alpha: p < 0.5 ? 1 : (1 - p) * 2);
                canvas.drawRRect(
                    RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size, height: size),
                        Radius.circular(size * 0.25)),
                    paint);
              },
            ),
          );
        },
      ),
    );
  }

  // ---------- input: press, hold and drag anywhere ----------

  Vector2 _toField(Vector2 canvasPoint) => camera.viewport.globalToLocal(canvasPoint);

  /// The speaker button, bottom-left on the title and game-over screens (field units).
  Rect get muteButton => Rect.fromLTWH(10, state.height - safeBottom - 44, 32, 32);

  bool get showsMuteButton => state.mode != GameMode.playing;

  /// The shop button, bottom-right on the title and game-over screens (field units).
  Rect get shopButton => Rect.fromLTWH(GameState.width - 102, state.height - safeBottom - 44, 92, 32);

  bool get showsShopButton => !shop.isOpen && !book.isOpen && (state.mode == GameMode.title || state.showGameOver);

  /// The memories book's button, bottom-centre on the title and game-over screens.
  Rect get memoriesButton => Rect.fromLTWH((GameState.width - 132) / 2, state.height - safeBottom - 44, 132, 32);

  bool get showsMemoriesButton => showsShopButton;

  /// Something in the shop that isn't owned yet costs no more than the coins in the bank.
  bool get canBuySomething =>
      [...Shop.skins, ...Shop.trails].any((item) => !state.owns(item) && state.canAfford(item));

  void toggleMute() {
    muted = !muted;
    onMuteChanged?.call(muted);
  }

  void _startSound() {
    music.start();
    sfx.load();
  }

  /// A press at [field] (field units). Returns false if it went to a button or the shop
  /// instead of starting or steering the bunny.
  bool press(Vector2 field, {required bool touch}) {
    _startSound(); // the first tap is when browsers allow sound
    final point = Offset(field.x, field.y);
    if (showsMuteButton && muteButton.inflate(6).contains(point)) {
      toggleMute();
      return false;
    }
    if (shop.isOpen) {
      shop.press(point);
      return false;
    }
    if (book.isOpen) {
      book.press(point);
      return false;
    }
    if (showsMemoriesButton && memoriesButton.inflate(4).contains(point)) {
      book.open();
      sfx.play(const SoundCue(Sfx.click));
      return false;
    }
    if (showsShopButton && shopButton.inflate(6).contains(point)) {
      shop.open();
      sfx.play(const SoundCue(Sfx.click));
      return false;
    }
    state.pointerDown(field.x, field.y, touch: touch);
    return true;
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      toggleMute();
      return KeyEventResult.handled;
    }
    if (state.readingMemory &&
        (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter)) {
      state.continueMemory();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && (shop.isOpen || book.isOpen)) {
      shop.close();
      book.close();
      return KeyEventResult.handled;
    }
    if (book.isOpen && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      book.turn(-1);
      return KeyEventResult.handled;
    }
    if (book.isOpen && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      book.turn(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_pointer != null) return;
    final touch = event.deviceKind == PointerDeviceKind.touch || event.deviceKind == PointerDeviceKind.stylus;
    if (press(_toField(event.canvasPosition), touch: touch)) _pointer = event.pointerId;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (event.pointerId != _pointer) return;
    final p = _toField(event.canvasEndPosition);
    state.pointerMove(p.x, p.y);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == _pointer) release();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId == _pointer) release();
  }

  /// Let go of the bunny (also used when the app loses focus).
  void release() {
    _pointer = null;
    state.pointerUp();
  }

  @override
  void onRemove() {
    _sprites?.dispose();
    _sprites = null;
    music.dispose();
    sfx.dispose();
    super.onRemove();
  }
}
