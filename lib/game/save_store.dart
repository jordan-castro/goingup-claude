import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// Keeps the best run, the last run (screens and crash point), the coin total and the
/// music on/off choice on the device.
class SaveStore {
  SaveStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _bestKey = 'best';
  static const _coinsKey = 'coins';
  static const _lastScreensKey = 'lastScreens';
  static const _crashYKey = 'crashY';
  static const _crashXKey = 'crashX';
  static const _mutedKey = 'muted';

  bool get muted => _prefs.getBool(_mutedKey) ?? false;
  Future<void> setMuted(bool value) => _prefs.setBool(_mutedKey, value);

  static Future<SaveStore> open() async => SaveStore._(await SharedPreferences.getInstance());

  SavedProgress read() => SavedProgress(
        best: _prefs.getInt(_bestKey) ?? 0,
        coins: _prefs.getInt(_coinsKey) ?? 0,
        lastScreens: _prefs.getInt(_lastScreensKey),
        crashY: _prefs.getDouble(_crashYKey),
        crashX: _prefs.getDouble(_crashXKey),
      );

  Future<void> write(SavedProgress progress) async {
    await _prefs.setInt(_bestKey, progress.best);
    await _prefs.setInt(_coinsKey, progress.coins);
    final lastScreens = progress.lastScreens;
    if (lastScreens != null) await _prefs.setInt(_lastScreensKey, lastScreens);
    final crashY = progress.crashY, crashX = progress.crashX;
    if (crashY != null && crashX != null) {
      await _prefs.setDouble(_crashYKey, crashY);
      await _prefs.setDouble(_crashXKey, crashX);
    }
  }
}
