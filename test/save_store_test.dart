import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/game_state.dart';
import 'package:goingup/game/save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('best run, last run and coins survive a round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open();
    expect(store.read().best, 0);
    expect(store.read().coins, 0);

    await store.write(const SavedProgress(best: 23, coins: 310, lastScreens: 17, crashY: 12500.5, crashX: 143.25));
    final again = await SaveStore.open();
    final saved = again.read();
    expect(saved.best, 23);
    expect(saved.coins, 310);
    expect(saved.lastScreens, 17);
    expect(saved.crashY, 12500.5);
    expect(saved.crashX, 143.25);
  });

  test('the music on/off choice is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open();
    expect(store.muted, isFalse);
    await store.setMuted(true);
    expect((await SaveStore.open()).muted, isTrue);
  });
}
