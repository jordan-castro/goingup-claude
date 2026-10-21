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
import 'components/hud.dart';
import 'components/pickups.dart';
import 'components/starfield.dart';
import 'components/trail.dart';
import 'components/tunnel.dart';
import 'game_state.dart';
import 'music.dart';
import 'palette.dart';
import 'sprites.dart';

/// The Flame side of goingUP: runs [state] every frame and shows (and plays) it.
///
/// World coordinates are (x, -worldY), so up the tunnel is up the screen. The camera's
/// viewport is always [GameState.width] wide with a height that follows the screen's shape
/// (between a 1.6 and 2.175 aspect, letterboxed beyond that), and the viewfinder scrolls with
/// the distance flown.
class GoingUpGame extends FlameGame with DragCallbacks, KeyboardEvents {
  GoingUpGame({GameState? state, GameMusic? music})
      : state = state ?? GameState(),
        music = music ?? SilentMusic();

  final GameState state;
  final GameMusic music;

  /// Called when the player mutes or unmutes, so the choice can be saved.
  void Function(bool muted)? onMuteChanged;

  /// The run's mood (0 bright, 1 dark and mystic), eased so changes are gradual: the picture
  /// and music follow this rather than [GameState.mood] directly.
  double mood = 0;

  Sprites? _sprites;
  Sprites get sprites => _sprites!;
  late final List<Component> _overlays; // field-space layers in the viewport, over the world
  final _rng = math.Random();
  int? _pointer; // the one pointer that steers; extra fingers are ignored

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
    _overlays = [Atmosphere(), Hud()];
    camera = CameraComponent(
      world: world,
      viewport: FixedResolutionViewport(resolution: Vector2(GameState.width, state.height)),
      backdrop: Starfield(),
    );
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewport.addAll(_overlays);
    world.addAll([Trail(), Tunnel(), PickupLayer(), CrashMarkerView(), BunnyView()]);
    _followState();
    if (!kIsWeb) music.start(); // browsers only allow sound after a tap or click
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
    final target = state.mood;
    final rate = target < mood ? 1.5 : 4.0; // a new run brightens back over a couple of seconds
    mood += (target - mood) * (1 - math.exp(-rate * math.min(dt, 0.1)));
    music.update(mood, quiet: state.mode == GameMode.dead);
    _followState();
    super.update(dt);
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

  void toggleMute() {
    music.muted = !music.muted;
    onMuteChanged?.call(music.muted);
  }

  /// A press at [field] (field units). Returns false if it hit the mute button instead of
  /// starting or steering the bunny.
  bool press(Vector2 field, {required bool touch}) {
    music.start(); // the first tap is when browsers allow sound
    if (showsMuteButton && muteButton.inflate(6).contains(Offset(field.x, field.y))) {
      toggleMute();
      return false;
    }
    state.pointerDown(field.x, field.y, touch: touch);
    return true;
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyM) {
      toggleMute();
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
    super.onRemove();
  }
}
