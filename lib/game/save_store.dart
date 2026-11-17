import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// Keeps the best run, the last run (screens and crash point), the coins in the bank, the
/// shop items bought and worn, the memories found, and the sound on/off choice on the device.
class SaveStore {
  SaveStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _bestKey = 'best';
  static const _coinsKey = 'coins';
  static const _lastScreensKey = 'lastScreens';
  static const _crashYKey = 'crashY';
  static const _crashXKey = 'crashX';
  static const _mutedKey = 'muted';
  static const _ownedKey = 'owned';
  static const _skinKey = 'skin';
  static const _trailKey = 'trail';
  static const _memoriesKey = 'memories';
  static const _watchedKey = 'watched';
  static const _turbosKey = 'turbos';
  static const _tripleShieldsKey = 'tripleShields';
  static const _languageKey = 'language';

  /// The language chosen with the EN / ES button ('en' or 'es'), or null if never chosen.
  String? get language => _prefs.getString(_languageKey);
  Future<void> setLanguage(String value) => _prefs.setString(_languageKey, value);

  bool get muted => _prefs.getBool(_mutedKey) ?? false;
  Future<void> setMuted(bool value) => _prefs.setBool(_mutedKey, value);

  static Future<SaveStore> open() async => SaveStore._(await SharedPreferences.getInstance());

  SavedProgress read() => SavedProgress(
        best: _prefs.getInt(_bestKey) ?? 0,
        coins: _prefs.getInt(_coinsKey) ?? 0,
        lastScreens: _prefs.getInt(_lastScreensKey),
        crashY: _prefs.getDouble(_crashYKey),
        crashX: _prefs.getDouble(_crashXKey),
        owned: _prefs.getStringList(_ownedKey) ?? const [],
        skin: _prefs.getString(_skinKey),
        trail: _prefs.getString(_trailKey),
        memories: _prefs.getStringList(_memoriesKey) ?? const [],
        watched: _prefs.getStringList(_watchedKey) ?? const [],
        turbos: _prefs.getInt(_turbosKey) ?? 0,
        tripleShields: _prefs.getInt(_tripleShieldsKey) ?? 0,
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
    await _prefs.setStringList(_ownedKey, progress.owned);
    final skin = progress.skin, trail = progress.trail;
    if (skin != null) await _prefs.setString(_skinKey, skin);
    if (trail != null) await _prefs.setString(_trailKey, trail);
    await _prefs.setStringList(_memoriesKey, progress.memories);
    await _prefs.setStringList(_watchedKey, progress.watched);
    await _prefs.setInt(_turbosKey, progress.turbos);
    await _prefs.setInt(_tripleShieldsKey, progress.tripleShields);
  }
}
