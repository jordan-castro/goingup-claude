import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/music.dart';

void main() {
  test('the bright start is all day music, full night is mostly night music', () {
    final start = musicMix(0);
    expect(start.day, 1);
    expect(start.dusk, 0);
    expect(start.night, 0);

    final end = musicMix(1);
    expect(end.day, 0);
    expect(end.night, 1);
    expect(end.dusk, lessThan(0.5), reason: 'a little warmth stays under the night');
  });

  test('the layers crossfade smoothly: day only fades, night only grows', () {
    var last = musicMix(0);
    for (var i = 1; i <= 100; i++) {
      final m = musicMix(i / 100);
      expect(m.day, lessThanOrEqualTo(last.day + 1e-12));
      expect(m.night, greaterThanOrEqualTo(last.night - 1e-12));
      for (final v in [m.day, m.dusk, m.night]) {
        expect(v, inInclusiveRange(0, 1));
      }
      expect((m.day - last.day).abs(), lessThan(0.06), reason: 'no sudden jumps');
      expect((m.night - last.night).abs(), lessThan(0.06));
      last = m;
    }
    // halfway the dusk pad carries the music
    final mid = musicMix(0.5);
    expect(mid.dusk, greaterThan(mid.day));
    expect(mid.dusk, greaterThan(mid.night));
  });
}
