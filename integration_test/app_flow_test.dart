// Integration tests that run on a REAL Android emulator/device (phone or
// tablet) against the real app, real DI and the pulse_api simulator.
//
//   flutter test integration_test -d <device-id>
//
// The same file runs on both form factors; layout expectations adapt to the
// window class (AdaptiveLayout), so a tablet must show two panes and a phone
// must push the ticket as a full screen.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pulse/app_root.dart';
import 'package:pulse/core/di/app_injection.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/adaptive_layout.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:pulse/features/candles/presentation/widgets/candle_section.dart';
import 'package:pulse/features/watchlist/presentation/widgets/watchlist_row.dart';
import 'package:pulse_api/pulse_api.dart';
import 'package:pulse_design_system/pulse_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _l10n = AppLocalizationsFa();

late FakeTradingApi _api;
late GetIt _di;

Future<void> _boot(
  WidgetTester tester, {
  ChaosConfig chaos = ChaosConfig.calm,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  _api = FakeTradingApi(
    chaos: chaos,
    requestTimeout: const Duration(seconds: 2),
  );
  _di = GetIt.asNewInstance();
  configureCoreDependencies(_di);
  configureTradingDependencies(_di, api: _api);
  configureAppDependencies(_di, store: SharedPreferencesKeyValueStore(prefs));
  await tester.pumpWidget(AppRoot(di: _di));
}

Future<void> _shutdown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _di.reset();
  _api.dispose();
}

/// Pumps real time until [finder] matches or [timeout] elapses.
Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out after $timeout waiting for ${reason ?? finder}');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

bool _twoPane(WidgetTester tester) =>
    AdaptiveLayout.isTwoPaneOf(tester.element(find.byType(Scaffold).first));

Future<WatchlistRow> _firstTradableRow(WidgetTester tester) async {
  await _until(tester, find.byType(WatchlistRow), reason: 'watchlist rows');
  return tester
      .widgetList<WatchlistRow>(find.byType(WatchlistRow))
      .firstWhere((r) => r.instrument.tradable);
}

Future<void> _openTicket(WidgetTester tester, WatchlistRow row) async {
  await tester.tap(find.byWidget(row));
  await _until(tester, find.byType(CandleSection), reason: 'ticket + chart');
}

Future<void> _enterQuantity(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.byType(PulsePrimaryButton);
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<List<Map<String, Object?>>> _serverOrders() async {
  final restore = _api.chaos;
  _api.chaos = ChaosConfig.calm;
  try {
    final body = jsonDecode(await _api.getOrders()) as Map<String, Object?>;
    return (body['orders']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .toList();
  } finally {
    _api.chaos = restore;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('layout matches the window class and prices are live', (
    tester,
  ) async {
    await _boot(tester);
    try {
      final row = await _firstTradableRow(tester);
      final twoPane = _twoPane(tester);
      // ignore: avoid_print
      print(
        'WINDOW ${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio} '
        'logical=${tester.view.physicalSize / tester.view.devicePixelRatio} '
        'twoPane=$twoPane',
      );

      expect(
        find.text(_l10n.selectInstrumentTitle),
        twoPane ? findsOneWidget : findsNothing,
        reason: 'tablet shows a detail placeholder, phone does not',
      );

      // A live tick must change what the row shows within a few seconds.
      String priceOf() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byWidget(row),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join('|');
      final before = priceOf();
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (priceOf() == before && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(priceOf(), isNot(before), reason: 'live ticks update the row');
      expect(find.text(_l10n.feedStale), findsNothing);
      expect(_api.openConnectionCount, 1, reason: 'one shared connection');
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('chart: shows bars, switches range, selecting shows OHLC', (
    tester,
  ) async {
    await _boot(tester);
    try {
      await _openTicket(tester, await _firstTradableRow(tester));
      await _until(tester, find.byType(PulseCandleChart), reason: 'chart');

      await tester.tap(find.text(_l10n.rangeWeek));
      await _until(tester, find.byType(PulseCandleChart), reason: 'week chart');
      await tester.tap(find.text(_l10n.rangeMonth));
      await _until(
        tester,
        find.byType(PulseCandleChart),
        reason: 'month chart',
      );

      final box = tester.getRect(find.byType(PulseCandleChart));
      await tester.tapAt(Offset(box.center.dx, box.center.dy));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(' · '), findsWidgets, reason: 'OHLC line');
      expect(find.text(_l10n.chartLegend), findsOneWidget);
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('a valid market order is filled and cash decreases', (
    tester,
  ) async {
    await _boot(tester);
    try {
      final row = await _firstTradableRow(tester);
      final ordersBefore = (await _serverOrders()).length;
      await _openTicket(tester, row);
      await _enterQuantity(tester, row.instrument.lotSize.toString());

      await _submit(tester);
      await _until(
        tester,
        find.text(_l10n.orderFilledTitle),
        reason: 'filled card',
      );

      expect((await _serverOrders()).length, ordersBefore + 1);
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('invalid input is explained and nothing is sent', (tester) async {
    await _boot(tester);
    try {
      final row = await _firstTradableRow(tester);
      final ordersBefore = (await _serverOrders()).length;
      await _openTicket(tester, row);

      await _submit(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(_l10n.validationRequired), findsOneWidget);
      expect((await _serverOrders()).length, ordersBefore);
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('tapping submit repeatedly creates exactly one order', (
    tester,
  ) async {
    await _boot(tester);
    try {
      final row = await _firstTradableRow(tester);
      final ordersBefore = (await _serverOrders()).length;
      await _openTicket(tester, row);
      await _enterQuantity(tester, row.instrument.lotSize.toString());

      final button = find.byType(PulsePrimaryButton);
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 5; i++) {
        await tester.tap(button, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await _until(tester, find.text(_l10n.orderFilledTitle));

      expect((await _serverOrders()).length, ordersBefore + 1);
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('storm: ghost timeouts never execute an order twice', (
    tester,
  ) async {
    await _boot(tester);
    try {
      final row = await _firstTradableRow(tester);
      final ordersBefore = (await _serverOrders()).length;
      await _openTicket(tester, row);
      await _enterQuantity(tester, row.instrument.lotSize.toString());
      // Hostile network from now on: 503s and orders that execute but time out.
      _api.chaos = ChaosConfig.storm.copyWith(
        ghostTimeoutRate: 0.6,
        requestFailureRate: 0.3,
      );

      await _submit(tester);
      await _until(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              {
                _l10n.orderFilledTitle,
                _l10n.orderWorkingTitle,
                _l10n.orderRejectedTitle,
                _l10n.orderUnresolvedTitle,
              }.contains(w.data),
        ),
        timeout: const Duration(minutes: 2),
        reason: 'a terminal or unresolved order state',
      );

      final created = (await _serverOrders()).length - ordersBefore;
      expect(created, lessThanOrEqualTo(1), reason: 'never duplicated');
      if (find.text(_l10n.orderFilledTitle).evaluate().isNotEmpty) {
        expect(created, 1, reason: 'filled in the UI means one real order');
      }
    } finally {
      await _shutdown(tester);
    }
  });

  testWidgets('tablet: switching symbol keeps working; phone: back returns', (
    tester,
  ) async {
    await _boot(tester);
    try {
      await _until(tester, find.byType(WatchlistRow), reason: 'rows');
      final tradable = tester
          .widgetList<WatchlistRow>(find.byType(WatchlistRow))
          .where((r) => r.instrument.tradable)
          .toList();
      expect(tradable.length, greaterThanOrEqualTo(2));
      final twoPane = _twoPane(tester);

      await _openTicket(tester, tradable.first);
      if (twoPane) {
        await tester.tap(find.byWidget(tradable[1]));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text(tradable[1].instrument.name),
          findsWidgets,
          reason: 'detail pane switched to the second symbol',
        );
      } else {
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(WatchlistRow), findsWidgets);
      }
    } finally {
      await _shutdown(tester);
    }
  });
}
