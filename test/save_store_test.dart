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

    await store.write(const SavedProgress(best: 230, coins: 310, lastMeters: 170, crashY: 12500.5, crashX: 143.25));
    final again = await SaveStore.open();
    final saved = again.read();
    expect(saved.best, 230);
    expect(saved.coins, 310);
    expect(saved.lastMeters, 170);
    expect(saved.crashY, 12500.5);
    expect(saved.crashX, 143.25);
  });

  test('runs counted in screens by older versions come back in meters', () async {
    SharedPreferences.setMockInitialValues({'best': 20, 'lastScreens': 11, 'coins': 5});
    final saved = (await SaveStore.open()).read();
    expect(saved.best, 130, reason: '20 screens of 720 units, at 110 units a meter');
    expect(saved.lastMeters, 72);
    expect(saved.coins, 5);

    final store = await SaveStore.open();
    await store.write(const SavedProgress(best: 140, lastMeters: 140));
    expect((await SaveStore.open()).read().best, 140, reason: 'once saved in meters, the meters count');
  });

  test('shop items bought and worn, and memories found, survive a round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open();
    expect(store.read().owned, isEmpty);
    expect(store.read().skin, isNull);

    await store.write(
        const SavedProgress(owned: ['berry', 'fire'], skin: 'berry', trail: 'fire', memories: ['sky-0', 'sky-1']));
    final saved = (await SaveStore.open()).read();
    expect(saved.memories, ['sky-0', 'sky-1']);
    expect(saved.owned, ['berry', 'fire']);
    expect(saved.skin, 'berry');
    expect(saved.trail, 'fire');
  });

  test('the music on/off choice is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open();
    expect(store.muted, isFalse);
    await store.setMuted(true);
    expect((await SaveStore.open()).muted, isTrue);
  });
}
