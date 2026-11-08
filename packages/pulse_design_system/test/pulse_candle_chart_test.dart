import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

PulseCandleBar _bar(double o, double h, double l, double c) =>
    PulseCandleBar(open: o, high: h, low: l, close: c);

void main() {
  group('CandleChartGeometry', () {
    const size = Size(300, 200);

    test('higher values are drawn nearer the top', () {
      final g = CandleChartGeometry(
        bars: [_bar(10, 20, 5, 15), _bar(15, 18, 12, 16)],
        size: size,
      );

      expect(g.yFor(20), lessThan(g.yFor(5)));
      expect(g.yFor(g.maxValue), closeTo(g.padding, 0.001));
      expect(g.yFor(g.minValue), closeTo(size.height - g.padding, 0.001));
    });

    test('range covers wicks and bodies', () {
      final g = CandleChartGeometry(bars: [_bar(10, 20, 5, 15)], size: size);

      expect(g.minValue, 5);
      expect(g.maxValue, 20);
    });

    test('a flat market gets a drawable range (no division by zero)', () {
      final g = CandleChartGeometry(bars: [_bar(10, 10, 10, 10)], size: size);

      expect(g.maxValue, greaterThan(g.minValue));
      expect(g.yFor(10).isFinite, isTrue);
    });

    test('a flat market at zero still has a range', () {
      final g = CandleChartGeometry(bars: [_bar(0, 0, 0, 0)], size: size);

      expect(g.maxValue - g.minValue, greaterThan(0));
    });

    test('no bars is safe', () {
      final g = CandleChartGeometry(bars: const [], size: size);

      expect(g.slotWidth, 0);
      expect(g.indexAt(10), isNull);
      expect(g.yFor(0.5).isFinite, isTrue);
    });

    test('slots, centers and body width scale with the bar count', () {
      final g = CandleChartGeometry(
        bars: List.filled(3, _bar(1, 2, 0.5, 1.5)),
        size: size,
      );

      expect(g.slotWidth, 100);
      expect(g.centerX(0), 50);
      expect(g.centerX(2), 250);
      expect(g.bodyWidth, 60);
    });

    test('bodies never shrink below one pixel with very many bars', () {
      final g = CandleChartGeometry(
        bars: List.filled(5000, _bar(1, 2, 0.5, 1.5)),
        size: size,
      );

      expect(g.bodyWidth, 1);
    });

    test('indexAt maps touches and clamps the edges', () {
      final g = CandleChartGeometry(
        bars: List.filled(3, _bar(1, 2, 0.5, 1.5)),
        size: size,
      );

      expect(g.indexAt(0), 0);
      expect(g.indexAt(99), 0);
      expect(g.indexAt(100), 1);
      expect(g.indexAt(299.9), 2);
      expect(g.indexAt(300), 2);
      expect(g.indexAt(-50), 0);
      expect(g.indexAt(9999), 2);
    });

    test('zero width gives no index', () {
      final g = CandleChartGeometry(
        bars: [_bar(1, 2, 0.5, 1.5)],
        size: const Size(0, 100),
      );

      expect(g.indexAt(5), isNull);
    });

    test('isUp is true for flat bars', () {
      expect(_bar(1, 1, 1, 1).isUp, isTrue);
      expect(_bar(2, 2, 1, 1).isUp, isFalse);
    });
  });

  group('PulseCandleChart', () {
    Widget host(Widget chart, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? PulseTheme.light(),
      home: Scaffold(body: chart),
    );

    testWidgets('exposes a spoken summary', (t) async {
      await t.pumpWidget(
        host(
          PulseCandleChart(
            bars: [_bar(1, 2, 0.5, 1.5)],
            semanticsLabel: 'Chart of A',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Chart of A'), findsOneWidget);
    });

    testWidgets('empty data draws without crashing', (t) async {
      await t.pumpWidget(
        host(const PulseCandleChart(bars: [], semanticsLabel: 'empty')),
      );

      expect(t.takeException(), isNull);
    });

    testWidgets('tapping selects the bar under the finger', (t) async {
      int? picked;
      await t.pumpWidget(
        host(
          PulseCandleChart(
            bars: List.filled(4, _bar(1, 2, 0.5, 1.5)),
            semanticsLabel: 'c',
            onSelected: (i) => picked = i,
          ),
        ),
      );
      final box = t.getRect(find.byType(PulseCandleChart));

      await t.tapAt(Offset(box.left + box.width * 0.9, box.center.dy));

      expect(picked, 3);
    });

    testWidgets('dragging updates the selection', (t) async {
      final picked = <int>[];
      await t.pumpWidget(
        host(
          PulseCandleChart(
            bars: List.filled(4, _bar(1, 2, 0.5, 1.5)),
            semanticsLabel: 'c',
            onSelected: picked.add,
          ),
        ),
      );
      final box = t.getRect(find.byType(PulseCandleChart));

      await t.dragFrom(
        Offset(box.left + 5, box.center.dy),
        Offset(box.width * 0.8, 0),
      );

      expect(picked, isNotEmpty);
      expect(picked.last, 3, reason: 'dragged to the right end');
    });

    testWidgets('renders in dark theme and RTL', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: PulseTheme.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PulseCandleChart(
                bars: [_bar(1, 2, 0.5, 1.5), _bar(1.5, 2, 1, 1.2)],
                semanticsLabel: 'c',
                selectedIndex: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('an out-of-range selectedIndex is ignored safely', (t) async {
      await t.pumpWidget(
        host(
          PulseCandleChart(
            bars: [_bar(1, 2, 0.5, 1.5)],
            semanticsLabel: 'c',
            selectedIndex: 99,
          ),
        ),
      );

      expect(t.takeException(), isNull);
    });
  });
}
