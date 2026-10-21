import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goingup/game/game_screen.dart';
import 'package:goingup/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the app starts, and pressing and holding starts a run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GoingUpApp(music: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GameScreen), findsOneWidget);

    final centre = tester.getCenter(find.byType(GameScreen));
    final gesture = await tester.startGesture(centre, kind: PointerDeviceKind.touch);
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
