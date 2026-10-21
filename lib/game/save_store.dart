import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// Keeps the best run, the last run (meters and crash point), the coins in the bank, the
/// shop items bought and worn, the memories found, and the sound on/off choice on the device.
class SaveStore {
  SaveStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _bestKey = 'bestMeters';
  static const _lastKey = 'lastMeters';
  static const _coinsKey = 'coins';
  static const _crashYKey = 'crashY';
  static const _crashXKey = 'crashX';
  static const _mutedKey = 'muted';
  static const _ownedKey = 'owned';
  static const _skinKey = 'skin';
  static const _trailKey = 'trail';
  static const _memoriesKey = 'memories';

  /// Older versions counted screens flown, 720 units each.
  static const _oldBestKey = 'best', _oldLastKey = 'lastScreens';
  static const double _metersPerScreen = 720 / GameState.unitsPerMeter;

  bool get muted => _prefs.getBool(_mutedKey) ?? false;
  Future<void> setMuted(bool value) => _prefs.setBool(_mutedKey, value);

  static Future<SaveStore> open() async => SaveStore._(await SharedPreferences.getInstance());

  SavedProgress read() => SavedProgress(
        best: _prefs.getInt(_bestKey) ?? _fromScreens(_oldBestKey) ?? 0,
        coins: _prefs.getInt(_coinsKey) ?? 0,
        lastMeters: _prefs.getInt(_lastKey) ?? _fromScreens(_oldLastKey),
        crashY: _prefs.getDouble(_crashYKey),
        crashX: _prefs.getDouble(_crashXKey),
        owned: _prefs.getStringList(_ownedKey) ?? const [],
        skin: _prefs.getString(_skinKey),
        trail: _prefs.getString(_trailKey),
        memories: _prefs.getStringList(_memoriesKey) ?? const [],
      );

  int? _fromScreens(String key) {
    final screens = _prefs.getInt(key);
    return screens == null ? null : (screens * _metersPerScreen).floor();
  }

  Future<void> write(SavedProgress progress) async {
    await _prefs.setInt(_bestKey, progress.best);
    await _prefs.setInt(_coinsKey, progress.coins);
    final last = progress.lastMeters;
    if (last != null) await _prefs.setInt(_lastKey, last);
    final crashY = progress.crashY, crashX = progress.crashX;
    if (crashY != null && crashX != null) {
      await _prefs.setDouble(_crashYKey, crashY);
      await _prefs.setDouble(_crashXKey, crashX);
    }
    await _prefs.setStringList(_ownedKey, progress.owned);
    final skin = progress.skin, trail = progress.trail;
    if (skin != null) await _prefs.setString(_skinKey, skin);
    if (trail != null) await _prefs.setString(_trailKey, trail);
    await _prefs.setStringList(_memoriesKey, progress.memories);
  }
}
