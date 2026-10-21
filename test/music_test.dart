import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/music.dart';

void main() {
  test('each realm has its own sound: day, dusk, the broken music box, then the void', () {
    final sky = musicMix(0, 0);
    expect((sky.day, sky.dusk, sky.creep, sky.night, sky.abyss), (1.0, 0.0, 0.0, 0.0, 0.0));

    final twilight = musicMix(0.28, 0);
    expect(twilight.dusk, greaterThan(0.9));
    expect(twilight.day, lessThan(0.1));

    final hollow = musicMix(0.8, 0);
    expect(hollow.creep, 1.0, reason: 'the lullaby on a broken music box');
    expect(hollow.night, greaterThan(0.5));
    expect(hollow.day + hollow.dusk, 0);

    final abyss = musicMix(1, 1);
    expect(abyss.abyss, 1.0, reason: 'the heartbeat of the void');
    expect(abyss.abyss, greaterThan(abyss.creep));
  });

  test('the layers crossfade smoothly all the way up', () {
    var last = musicMix(0, 0);
    for (var i = 1; i <= 2000; i++) {
      final mood = (i / 1000).clamp(0.0, 1.0), deep = ((i - 1000) / 1000).clamp(0.0, 1.0);
      final m = musicMix(mood, deep);
      final now = [m.day, m.dusk, m.creep, m.night, m.abyss];
      final before = [last.day, last.dusk, last.creep, last.night, last.abyss];
      for (var k = 0; k < now.length; k++) {
        expect(now[k], inInclusiveRange(0, 1));
        expect((now[k] - before[k]).abs(), lessThan(0.02), reason: 'no sudden jumps (layer $k at step $i)');
      }
      last = m;
    }
  });
}
