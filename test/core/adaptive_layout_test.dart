import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/presentation/adaptive_layout.dart';

void main() {
  test('phones in portrait use one pane', () {
    expect(AdaptiveLayout.isTwoPane(const Size(360, 800)), isFalse);
    expect(AdaptiveLayout.isTwoPane(const Size(412, 915)), isFalse);
  });

  test('phones in landscape (wide but short) still use one pane', () {
    expect(AdaptiveLayout.isTwoPane(const Size(800, 360)), isFalse);
    expect(AdaptiveLayout.isTwoPane(const Size(915, 412)), isFalse);
  });

  test('tablets in both orientations use two panes', () {
    expect(AdaptiveLayout.isTwoPane(const Size(800, 1280)), isTrue);
    expect(AdaptiveLayout.isTwoPane(const Size(1280, 800)), isTrue);
  });

  test('boundaries: 600x480 is the smallest two-pane window', () {
    expect(AdaptiveLayout.isTwoPane(const Size(600, 480)), isTrue);
    expect(AdaptiveLayout.isTwoPane(const Size(599.9, 480)), isFalse);
    expect(AdaptiveLayout.isTwoPane(const Size(600, 479.9)), isFalse);
  });

  test('zero or tiny sizes never throw', () {
    expect(AdaptiveLayout.isTwoPane(Size.zero), isFalse);
  });

  testWidgets('isTwoPaneOf reads the window size', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late bool result;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          result = AdaptiveLayout.isTwoPaneOf(context);
          return const SizedBox();
        },
      ),
    );

    expect(result, isTrue);
  });
}
