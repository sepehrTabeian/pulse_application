import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:pulse/features/watchlist/presentation/pages/watchlist_page.dart';

import '../../support/fakes.dart';
import '../../support/page_harness.dart';

final _l10n = AppLocalizationsFa();

_Page? _active;

/// Like testWidgets, but shuts the feed down BEFORE the test ends, because
/// flutter_test checks for pending timers before running tear-downs.
void pageTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      unawaited(_active?.close());
      _active = null;
      await tester.pumpWidget(const SizedBox());
    }
  });
}

class _Page {
  _Page(this.backend, this.source, this.store, this.lookup) {
    feed = PriceFeedCubit(
      PriceFeedService(source: source, clock: const SystemClock()),
    );
    watchlist = WatchlistCubit(
      loadWatchlist: LoadWatchlist(reader: backend, catalog: backend),
      writer: backend,
      mapper: const PulseApiExceptionMapper(),
    );
    portfolio = PortfolioCubit(
      reader: backend,
      mapper: const PulseApiExceptionMapper(),
    );
    recovery = OrderRecoveryCubit(
      ReconcilePendingOrders(lookup: lookup, store: store),
    );
  }

  final FakeBackend backend;
  final FakeFeedSource source;
  final InMemoryPendingOrderStore store;
  final ScriptedPlacer lookup;
  late final PriceFeedCubit feed;
  late final WatchlistCubit watchlist;
  late final PortfolioCubit portfolio;
  late final OrderRecoveryCubit recovery;
  final List<Instrument> opened = [];
  int searchOpened = 0;

  Widget widget() {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: feed),
        BlocProvider.value(value: watchlist),
        BlocProvider.value(value: portfolio),
        BlocProvider.value(value: recovery),
      ],
      child: PulseApp(
        home: WatchlistPage(
          resolver: const DefaultErrorMessageResolver(),
          onOpenTicket: (_, instrument) => opened.add(instrument),
          onOpenSearch: (_) => searchOpened++,
        ),
      ),
    );
  }

  Future<void> close() async {
    await feed.close();
    await watchlist.close();
    await portfolio.close();
    await recovery.close();
  }
}

Future<_Page> _pump(
  WidgetTester tester, {
  FakeBackend? backend,
  bool load = true,
}) async {
  final page = _Page(
    backend ?? FakeBackend(),
    FakeFeedSource(),
    InMemoryPendingOrderStore(),
    ScriptedPlacer([fills()]),
  );
  _active = page;
  await tester.pumpWidget(page.widget());
  if (load) {
    await page.watchlist.load();
    await page.portfolio.load();
    page.feed.setWatchlistSymbols(page.watchlist.state.symbols);
    await tester.pump();
  }
  return page;
}

void main() {
  group('states', () {
    pageTest('shows loading, then the rows', (tester) async {
      final page = await _pump(tester, load: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await page.watchlist.load();
      await tester.pump();

      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('HALT'), findsOneWidget);
    });

    pageTest('empty watchlist shows the empty state with an add action', (
      tester,
    ) async {
      final page = await _pump(tester, backend: FakeBackend(watchlist: []));

      expect(find.text(_l10n.watchlistEmptyTitle), findsOneWidget);
      await tester.tap(find.text(_l10n.actionAdd).last);
      expect(page.searchOpened, 1);
    });

    pageTest('failure shows the localized reason and retry works', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..loadError = const ServiceUnavailableException();
      await _pump(tester, backend: backend);

      expect(find.text(_l10n.watchlistLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.errorServiceUnavailable), findsOneWidget);

      backend.loadError = null;
      await tester.tap(find.text(_l10n.actionRetry));
      await tester.pump();
      await tester.pump();

      expect(find.text('AAPL'), findsOneWidget);
    });

    pageTest('tapping a row opens its ticket', (tester) async {
      final page = await _pump(tester);

      await tester.tap(find.text('AAPL'));

      expect(page.opened.single.symbol, 'AAPL');
    });
  });

  group('live prices', () {
    pageTest('a tick updates the price, change and direction', (tester) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('101.50'), findsOneWidget);
      expect(find.text('+1.50 (+1.50%)'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      page.source.tick('AAPL', '98.00', 2);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('98.00'), findsOneWidget);
      expect(find.text('-2.00 (-2.00%)'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    pageTest('direction is not conveyed by colour alone', (tester) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '100.00'});
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    pageTest('an old duplicate tick does not change the display', (
      tester,
    ) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.00'});
      page.source.tick('AAPL', '105.00', 5);
      await tester.pump(const Duration(milliseconds: 300));

      page.source.tick('AAPL', '90.00', 3);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('105.00'), findsOneWidget);
      expect(find.text('90.00'), findsNothing);
    });

    pageTest('a halted instrument shows a badge and the previous close', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text(_l10n.haltedBadge), findsOneWidget);
      expect(find.text('40.00'), findsOneWidget);
    });

    pageTest('a row without a price yet shows a placeholder', (tester) async {
      await _pump(tester);

      expect(find.text('—'), findsWidgets);
    });

    pageTest('rows expose a spoken description with direction', (tester) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.bySemanticsLabel(RegExp(_l10n.directionUp)), findsOneWidget);
    });
  });

  group('staleness (ADR-0007)', () {
    pageTest('silence shows the stale banner, dims rows, info explains', (
      tester,
    ) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_l10n.feedStale), findsNothing);

      await tester.pump(const Duration(seconds: 7));

      expect(find.textContaining(_l10n.feedStale), findsOneWidget);
      expect(find.text(_l10n.staleBadge), findsWidgets);

      await tester.tap(find.byTooltip(_l10n.actionMoreInfo).first);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.feedInfoBody), findsOneWidget);
    });

    pageTest('long silence turns the banner into the offline message', (
      tester,
    ) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pump(const Duration(seconds: 16));

      expect(find.textContaining(_l10n.feedOffline), findsOneWidget);
    });

    pageTest('heartbeats keep the banner away', (tester) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 2));
        page.source.send(const PriceHeartbeat());
      }

      expect(find.textContaining(_l10n.feedStale), findsNothing);
    });
  });

  group('swipe to delete and drag to reorder', () {
    Future<void> swipeAway(WidgetTester tester, String symbol) async {
      await tester.drag(find.text(symbol).first, const Offset(-800, 0));
      await tester.pumpAndSettle();
    }

    pageTest('swiping a row away removes the symbol and saves it', (
      tester,
    ) async {
      final page = await _pump(tester);

      await swipeAway(tester, 'AAPL');

      expect(page.backend.server, ['HALT']);
      expect(find.text('AAPL'), findsNothing);
    });

    pageTest('a failed delete rolls back and tells the user', (tester) async {
      final backend = FakeBackend()
        ..putError = const ServiceUnavailableException();
      await _pump(tester, backend: backend);

      await swipeAway(tester, 'AAPL');

      expect(find.text('AAPL'), findsOneWidget);
      expect(
        find.textContaining(_l10n.watchlistSaveRolledBack),
        findsOneWidget,
      );

      // The snackbar offers a retry that re-applies and saves the edit.
      backend.putError = null;
      final action = find.byType(SnackBarAction);
      expect(action, findsOneWidget);
      tester.widget<SnackBarAction>(action).onPressed();
      await tester.pumpAndSettle();
      expect(backend.server, ['HALT']);
      expect(find.text('AAPL'), findsNothing);
    });

    pageTest('dragging the handle moves a row and saves the new order', (
      tester,
    ) async {
      final page = await _pump(tester);

      final handle = find.byIcon(Icons.drag_indicator).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(page.backend.server, ['HALT', 'AAPL']);
    });
  });

  group('connection loss and recovery', () {
    pageTest('a socket error shows the banner and a reconnect clears it', (
      tester,
    ) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(_l10n.feedOffline), findsNothing);

      page.source.controllers.last.addError(Exception('socket closed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final banner = find.textContaining(_l10n.feedOffline);
      final reconnecting = find.textContaining(_l10n.feedConnecting);
      expect(
        banner.evaluate().isNotEmpty || reconnecting.evaluate().isNotEmpty,
        isTrue,
        reason: 'user is told the connection dropped',
      );
      final before = page.source.controllers.length;

      // Backoff elapses, a new connection opens and delivers a snapshot.
      await tester.pump(const Duration(seconds: 3));
      expect(page.source.controllers.length, greaterThan(before));
      page.source.snapshot({'AAPL': '102.00'});
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining(_l10n.feedOffline), findsNothing);
      expect(find.textContaining(_l10n.feedConnecting), findsNothing);
      expect(find.textContaining(_l10n.feedStale), findsNothing);
      expect(find.text('102.00'), findsOneWidget);
    });

    pageTest('a closed socket reconnects on its own', (tester) async {
      final page = await _pump(tester);
      page.source.snapshot({'AAPL': '101.50'});
      await tester.pump(const Duration(milliseconds: 300));
      final before = page.source.controllers.length;

      await page.source.controllers.last.close();
      await tester.pump(const Duration(seconds: 3));

      expect(page.source.controllers.length, greaterThan(before));
    });
  });

  group('stocks and crypto are separated', () {
    Instrument coin() => Instrument(
      symbol: 'BTC-USD',
      name: 'Bitcoin',
      type: InstrumentType.crypto,
      exchange: 'X',
      currency: 'USD',
      tickSize: Decimal.parse('0.01'),
      lotSize: Decimal.parse('0.0001'),
      prevClose: Decimal.parse('100'),
      tradable: true,
      unit: 'BTC',
    );

    FakeBackend mixed() => FakeBackend(
      instruments: [
        testInstrument(symbol: 'AAPL'),
        coin(),
      ],
      watchlist: ['AAPL', 'BTC-USD'],
    );

    pageTest('the switch shows only stocks or only crypto', (tester) async {
      await _pump(tester, backend: mixed());
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('BTC-USD'), findsOneWidget);

      await tester.tap(find.text(_l10n.assetCrypto));
      await tester.pumpAndSettle();
      expect(find.text('BTC-USD'), findsOneWidget);
      expect(find.text('AAPL'), findsNothing);

      await tester.tap(find.text(_l10n.assetStock));
      await tester.pumpAndSettle();
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('BTC-USD'), findsNothing);

      await tester.tap(find.text(_l10n.assetAll));
      await tester.pumpAndSettle();
      expect(find.text('BTC-USD'), findsOneWidget);
    });

    pageTest('reordering is only offered on the full list', (tester) async {
      await _pump(tester, backend: mixed());
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

      await tester.tap(find.text(_l10n.assetCrypto));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_indicator), findsNothing);
    });

    pageTest('an empty category says so', (tester) async {
      await _pump(
        tester,
        backend: FakeBackend(
          instruments: [
            testInstrument(symbol: 'AAPL'),
            coin(),
          ],
          watchlist: ['AAPL'],
        ),
      );

      await tester.tap(find.text(_l10n.assetCrypto));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.watchlistAssetEmpty), findsOneWidget);
    });
  });

  group('holdings tab (what the user owns)', () {
    Account owned() => Account(
      currency: 'USD',
      cash: Decimal.parse('1000'),
      positions: [
        Position(symbol: 'AAPL', quantity: Decimal.fromInt(5)),
        Position(symbol: 'BTC-USD', quantity: Decimal.parse('0.5')),
      ],
    );

    Instrument coin() => Instrument(
      symbol: 'BTC-USD',
      name: 'Bitcoin',
      type: InstrumentType.crypto,
      exchange: 'X',
      currency: 'USD',
      tickSize: Decimal.parse('0.01'),
      lotSize: Decimal.parse('0.0001'),
      prevClose: Decimal.parse('100'),
      tradable: true,
      unit: 'BTC',
    );

    FakeBackend backend({List<String>? watching}) => FakeBackend(
      instruments: [
        testInstrument(symbol: 'AAPL'),
        coin(),
      ],
      watchlist: watching ?? ['AAPL'],
    )..account = owned();

    Future<void> openHoldings(WidgetTester tester) async {
      await tester.tap(find.text(_l10n.homeTabHoldings));
      await tester.pumpAndSettle();
    }

    pageTest('lists owned assets with value and amount, even off-watchlist', (
      tester,
    ) async {
      await _pump(tester, backend: backend());
      await openHoldings(tester);

      expect(find.text('AAPL Inc'), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget, reason: 'not watched');
      expect(find.text('5 ${_l10n.unitShare}'), findsOneWidget);
      expect(find.text('0.5 BTC'), findsOneWidget);
      expect(find.text('500.00 USD'), findsOneWidget); // 5 x prevClose
      expect(find.text('50.00 USD'), findsOneWidget); // 0.5 x prevClose
    });

    pageTest('says clearly which list is owned and which is followed', (
      tester,
    ) async {
      await _pump(tester, backend: backend());
      await openHoldings(tester);
      expect(find.text(_l10n.holdingsHint), findsOneWidget);
      expect(find.text(_l10n.watchlistHint), findsNothing);

      await tester.tap(find.text(_l10n.homeTabWatchlist));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.watchlistHint), findsOneWidget);
      expect(find.text(_l10n.holdingsHint), findsNothing);
    });

    pageTest('the class switch splits holdings into stocks and crypto', (
      tester,
    ) async {
      await _pump(tester, backend: backend());
      await openHoldings(tester);

      await tester.tap(find.text(_l10n.assetCrypto));
      await tester.pumpAndSettle();
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('AAPL Inc'), findsNothing);

      await tester.tap(find.text(_l10n.assetStock));
      await tester.pumpAndSettle();
      expect(find.text('AAPL Inc'), findsOneWidget);
      expect(find.text('Bitcoin'), findsNothing);
    });

    pageTest('no holdings shows an empty state that leads to the watchlist', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.reset);
      final empty = FakeBackend(
        instruments: [testInstrument(symbol: 'AAPL')],
        watchlist: ['AAPL'],
      );
      await _pump(tester, backend: empty);
      await openHoldings(tester);

      expect(find.text(_l10n.holdingsEmptyTitle), findsOneWidget);
      await tester.tap(find.text(_l10n.holdingsEmptyAction));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.watchlistHint), findsOneWidget);
    });

    pageTest('tapping a holding opens its order ticket', (tester) async {
      final page = await _pump(tester, backend: backend());
      await openHoldings(tester);

      await tester.tap(find.text('AAPL Inc'));

      expect(page.opened.single.symbol, 'AAPL');
    });

    pageTest('swiping does not delete a holding (only watchlist rows)', (
      tester,
    ) async {
      final page = await _pump(tester, backend: backend());
      await openHoldings(tester);

      await tester.drag(find.text('AAPL Inc'), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(find.text('AAPL Inc'), findsOneWidget);
      expect(page.backend.server, ['AAPL']);
    });
  });

  group('portfolio header (ADR-0008)', () {
    pageTest('shows cash, approximate value, sell-now value and info', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..account = Account(
          currency: 'USD',
          cash: Decimal.parse('1000'),
          positions: [Position(symbol: 'AAPL', quantity: Decimal.fromInt(5))],
        );
      final page = await _pump(tester, backend: backend);
      page.source.snapshot({'AAPL': '100.00'}, bid: '99.00');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1,000.00 USD'), findsOneWidget); // cash
      expect(find.text('500.00 USD'), findsOneWidget); // by last
      expect(find.text('495.00 USD'), findsOneWidget); // sell now (bid)
      expect(find.text('1,500.00 USD'), findsOneWidget); // total
    });

    pageTest('a failed account load shows a notice, not a crash', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..accountError = const ServiceUnavailableException();
      await _pump(tester, backend: backend);

      expect(find.text(_l10n.portfolioLoadFailed), findsOneWidget);
    });
  });

  group('order recovery notices (ORD-07)', () {
    pageTest('shows what the server said and can be dismissed', (tester) async {
      final page = await _pump(tester);
      page.store.items['old'] = PendingOrder(
        request: testRequest(id: 'old', symbol: 'AAPL'),
        createdAt: DateTime(2026),
      );
      page.lookup.onLookup = (id) async => testOrder(testRequest(id: id));

      await page.recovery.run();
      await tester.pump();

      expect(find.text(_l10n.recoveryFilled('AAPL')), findsOneWidget);
      await tester.tap(find.text(_l10n.actionDismiss));
      await tester.pump();
      expect(find.text(_l10n.recoveryFilled('AAPL')), findsNothing);
    });
  });
}
