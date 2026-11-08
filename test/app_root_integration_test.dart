// End-to-end widget test: real DI container, real repositories, real
// pulse_api simulator (ChaosConfig.instant). Nothing is mocked. It runs once
// with a phone-sized window and once with a tablet-sized window.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/app_root.dart';
import 'package:pulse/core/di/app_injection.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/features/candles/presentation/widgets/candle_section.dart';
import 'package:pulse/features/watchlist/presentation/widgets/watchlist_row.dart';
import 'package:pulse_api/pulse_api.dart';

import 'support/in_memory_kv_store.dart';

final _l10n = AppLocalizationsFa();

Future<void> _settle(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void _scenario(String name, Size size, {required bool twoPane}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeTradingApi(
      chaos: ChaosConfig.instant,
      requestTimeout: const Duration(milliseconds: 20),
    );
    final di = GetIt.asNewInstance();
    configureCoreDependencies(di);
    configureTradingDependencies(di, api: api);
    configureAppDependencies(di, store: InMemoryKeyValueStore());

    try {
      await tester.pumpWidget(AppRoot(di: di));
      await _settle(tester);
      // The home page opens on the holdings; the order flow starts from
      // the watchlist.
      await tester.tap(find.text(_l10n.homeTabWatchlist));
      await _settle(tester, 2);

      final rows = tester
          .widgetList<WatchlistRow>(find.byType(WatchlistRow))
          .toList();
      expect(rows, isNotEmpty, reason: 'seeded watchlist is shown');
      final tradable = rows.firstWhere((r) => r.instrument.tradable);
      expect(find.text(_l10n.feedStale), findsNothing);
      expect(api.openConnectionCount, 1, reason: 'exactly one connection');
      expect(
        find.text(_l10n.selectInstrumentTitle),
        twoPane ? findsOneWidget : findsNothing,
      );

      await tester.tap(find.byWidget(tradable));
      // Live ticks keep scheduling frames, so pumpAndSettle can never settle.
      await _settle(tester, 4);

      expect(find.byType(CandleSection), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        tradable.instrument.lotSize.toString(),
      );
      await tester.pump();
      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.tap(find.byType(FilledButton).last);
      await _settle(tester, 3);

      expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await di.reset();
      api.dispose();
    }
  });
}

void main() {
  _scenario(
    'phone: watchlist, chart and an order end to end',
    const Size(412, 915),
    twoPane: false,
  );
  _scenario(
    'tablet: two panes, chart and an order end to end',
    const Size(1000, 1400),
    twoPane: true,
  );
}
