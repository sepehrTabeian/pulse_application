import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/adaptive_layout.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/core/utils/id_generator.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/candles/presentation/widgets/candle_section.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';
import 'package:pulse/features/trading/presentation/widgets/ticket_pane_host.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:pulse/features/watchlist/presentation/pages/watchlist_page.dart';

import '../../support/candle_fakes.dart';
import '../../support/fakes.dart';
import '../../support/page_harness.dart';

final _l10n = AppLocalizationsFa();

class _Ids implements IdGenerator {
  int n = 0;
  @override
  String generate() => 'pane-${++n}';
}

class _App {
  _App(List<Future<Order> Function(OrderRequest)> steps)
    : backend = FakeBackend(watchlist: ['AAPL', 'BTC']),
      source = FakeFeedSource(),
      store = InMemoryPendingOrderStore(),
      placer = ScriptedPlacer(steps),
      candles = FakeCandleReader() {
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
      ReconcilePendingOrders(lookup: placer, store: store),
    );
  }

  final FakeBackend backend;
  final FakeFeedSource source;
  final InMemoryPendingOrderStore store;
  final ScriptedPlacer placer;
  final FakeCandleReader candles;
  late final PriceFeedCubit feed;
  late final WatchlistCubit watchlist;
  late final PortfolioCubit portfolio;
  late final OrderRecoveryCubit recovery;
  final List<Instrument> opened = [];

  OrderFlowBloc _flow() => OrderFlowBloc(
    submitOrder: SubmitOrder(
      placer: placer,
      store: store,
      backoff: RetryPolicy(
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(milliseconds: 400),
        random: Random(1),
      ),
      maxAttempts: 3,
    ),
    store: store,
    idGenerator: _Ids(),
  );

  Widget widget() => MultiBlocProvider(
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
        onOpenSearch: (_) {},
        ticketPaneBuilder: (context, instrument, onLockChanged) =>
            TicketPaneHost(
              instrument: instrument,
              createOrderFlow: _flow,
              createCandles: (symbol) => CandlesCubit(
                symbol: symbol,
                reader: candles,
                mapper: const PulseApiExceptionMapper(),
              ),
              resolver: const DefaultErrorMessageResolver(),
              onLockChanged: onLockChanged,
            ),
      ),
    ),
  );

  Future<void> close() async {
    await feed.close();
    await watchlist.close();
    await portfolio.close();
    await recovery.close();
  }
}

_App? _active;

void _responsiveTest(
  String name,
  Future<void> Function(WidgetTester tester, _App app) body, {
  Size size = const Size(800, 1280),
  List<Future<Order> Function(OrderRequest)>? steps,
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = _App(steps ?? [fills()]);
    _active = app;
    try {
      await tester.pumpWidget(app.widget());
      await app.watchlist.load();
      await app.portfolio.load();
      app.feed.setWatchlistSymbols(app.watchlist.state.symbols);
      await tester.pump();
      app.source.snapshot(
        {'AAPL': '101.00', 'BTC': '200.00'},
        bid: '99.00',
        ask: '101.00',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await body(tester, app);
    } finally {
      unawaited(_active?.close());
      _active = null;
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> _openRow(WidgetTester tester, String symbol) async {
  await tester.tap(find.text(symbol).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('breakpoints', () {
    _responsiveTest(
      'phone portrait: single pane, a row opens a full screen',
      (tester, app) async {
        await _openRow(tester, 'AAPL');

        expect(find.text(_l10n.selectInstrumentTitle), findsNothing);
        expect(app.opened.single.symbol, 'AAPL');
        expect(find.byType(CandleSection), findsNothing);
      },
      size: const Size(400, 800),
    );

    _responsiveTest(
      'phone landscape (wide but short) stays single pane',
      (tester, app) async {
        expect(find.text(_l10n.selectInstrumentTitle), findsNothing);
        expect(AdaptiveLayout.isTwoPane(const Size(800, 360)), isFalse);
      },
      size: const Size(800, 360),
    );

    _responsiveTest('tablet portrait: list and an empty detail pane', (
      tester,
      app,
    ) async {
      expect(find.text(_l10n.selectInstrumentTitle), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);
    });

    _responsiveTest('tablet landscape: list and an empty detail pane', (
      tester,
      app,
    ) async {
      expect(find.text(_l10n.selectInstrumentTitle), findsOneWidget);
    }, size: const Size(1280, 800));

    _responsiveTest(
      'the list pane keeps its fixed width on a wide window',
      (tester, app) async {
        final width = tester
            .getSize(find.byType(ReorderableListView).first)
            .width;

        expect(width, AdaptiveLayout.listPaneWidth);
      },
      size: const Size(1280, 800),
    );
  });

  group('master-detail', () {
    _responsiveTest('selecting a row shows ticket and chart beside the list', (
      tester,
      app,
    ) async {
      await _openRow(tester, 'AAPL');

      expect(app.opened, isEmpty, reason: 'no full-screen push on tablets');
      expect(find.text(_l10n.selectInstrumentTitle), findsNothing);
      expect(find.byType(CandleSection), findsOneWidget);
      expect(
        find.text('${_l10n.quantityLabel} (${_l10n.unitShare})'),
        findsOneWidget,
      );
      expect(find.text('AAPL'), findsWidgets, reason: 'list still visible');
      expect(app.candles.requests.single.$1, 'AAPL');
    });

    _responsiveTest('switching symbol when idle replaces the pane', (
      tester,
      app,
    ) async {
      await _openRow(tester, 'AAPL');
      await _openRow(tester, 'BTC');

      expect(app.candles.requests.map((r) => r.$1), ['AAPL', 'BTC']);
      expect(
        find.text('BTC Inc'),
        findsNWidgets(2),
        reason: 'list row + header',
      );
      expect(find.text('AAPL Inc'), findsOneWidget, reason: 'list row name');
    });

    _responsiveTest(
      'detail content never stretches beyond the max width',
      (tester, app) async {
        await _openRow(tester, 'AAPL');

        final field = tester.getSize(find.byType(TextField).first).width;

        expect(field, lessThanOrEqualTo(AdaptiveLayout.maxDetailContentWidth));
      },
      size: const Size(1600, 900),
    );

    _responsiveTest('an order can be placed from the pane', (
      tester,
      app,
    ) async {
      await _openRow(tester, 'AAPL');
      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();

      await tester.ensureVisible(find.byType(FilledButton).last);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
      expect(app.placer.sent.single.clientOrderId, 'pane-1');
    });
  });

  group('order safety in the two-pane layout', () {
    Completer<Order>? gate;

    _responsiveTest(
      'the list refuses to switch symbol while an order is in flight',
      (tester, app) async {
        await _openRow(tester, 'AAPL');
        await tester.enterText(find.byType(TextField).first, '10');
        await tester.pump();
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();

        await _openRow(tester, 'BTC');

        expect(find.text(_l10n.switchBlocked), findsOneWidget);
        expect(app.candles.requests.map((r) => r.$1), ['AAPL']);
        expect(app.placer.sent, hasLength(1));

        gate!.complete(testOrder(app.placer.sent.single));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.drag(find.byType(ListView).last, const Offset(0, -800));
        await tester.pump();
        expect(find.text(_l10n.orderFilledTitle), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        await _openRow(tester, 'BTC');
        expect(app.candles.requests.map((r) => r.$1), ['AAPL', 'BTC']);
      },
      steps: [
        (_) {
          gate = Completer<Order>();
          return gate!.future;
        },
      ],
    );

    _responsiveTest(
      'shrinking the window mid-order keeps the live order flow alive',
      (tester, app) async {
        await _openRow(tester, 'AAPL');
        await tester.enterText(find.byType(TextField).first, '10');
        await tester.pump();
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();

        tester.view.physicalSize = const Size(400, 900);
        await tester.pump();
        await tester.pump();

        expect(find.text(_l10n.orderSending), findsWidgets);
        expect(app.placer.sent, hasLength(1), reason: 'not re-sent');

        final gate2 = Completer<Order>();
        // Resolve the in-flight order so the test can finish cleanly.
        app.placer.steps
          ..clear()
          ..add((_) => gate2.future);
        gate2.complete(testOrder(app.placer.sent.single));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      },
      steps: [(_) => Completer<Order>().future],
    );
  });
}
