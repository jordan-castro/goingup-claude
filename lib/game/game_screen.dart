import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'game_state.dart';
import 'going_up_game.dart';
import 'music.dart';
import 'save_store.dart';
import 'sfx.dart';

/// Hosts the Flame game, plays its music and keeps its progress saved on the device.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.music = true});

  /// Whether to play the soundtrack and sound effects (tests turn it off: there's no audio
  /// plugin there).
  final bool music;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GoingUpGame _game = GoingUpGame(
    state: GameState(onSave: _save, onCrash: HapticFeedback.mediumImpact, onBump: HapticFeedback.lightImpact)
      ..touchUi = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS
      ..pauseForMemories = true,
    music: widget.music ? LayeredMusic() : SilentMusic(),
    sfx: widget.music ? PooledSfx() : SilentSfx(),
  )..onMuteChanged = _saveMuted;
  late final AppLifecycleListener _lifecycle;
  SaveStore? _store;
  SavedProgress? _unsaved;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: _letGo,
      onHide: _hide,
      onShow: _game.music.resume,
      onPause: _flushSave,
    );
    _loadSave();
  }

  Future<void> _loadSave() async {
    try {
      final store = await SaveStore.open();
      if (!mounted) return;
      _store = store;
      _game.muted = store.muted;
      _game.state.restore(store.read());
      if (_unsaved != null) {
        _unsaved = _game.state.progress; // progress made before loading finished, merged with the save
        _flushSave();
      }
    } catch (_) {
      // Storage isn't available (for example in a locked-down browser): play without saving.
    }
  }

  /// Coins can arrive many times a second, so writes are batched: the latest progress is
  /// written at most every 0.6 s, and straight away when the app is backgrounded or closed.
  void _save(SavedProgress progress) {
    _unsaved = progress;
    _saveTimer ??= Timer(const Duration(milliseconds: 600), _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final progress = _unsaved, store = _store;
    if (progress == null || store == null) return;
    _unsaved = null;
    store.write(progress).catchError((Object _) {});
  }

  void _saveMuted(bool muted) {
    _store?.setMuted(muted).catchError((Object _) => false);
  }

  void _letGo() {
    _game.release();
    _flushSave();
  }

  void _hide() {
    _letGo();
    _game.music.pause();
  }

  @override
  void dispose() {
    _flushSave();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _game.safePadding = MediaQuery.paddingOf(context);
    return GameWidget(game: _game, mouseCursor: SystemMouseCursors.precise);
  }
}
