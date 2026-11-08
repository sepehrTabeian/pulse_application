import 'dart:async';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/l10n/generated/app_localizations_fa.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/core/utils/id_generator.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/pages/ticket_page.dart';

import '../../../support/fakes.dart';
import '../../../support/page_harness.dart';

final _l10n = AppLocalizationsFa();

class _Ids implements IdGenerator {
  int n = 0;
  @override
  String generate() => 'ticket-${++n}';
}

class _Ticket {
  _Ticket(this.instrument, List<Future<Order> Function(OrderRequest)> steps)
    : placer = ScriptedPlacer(steps),
      store = InMemoryPendingOrderStore(),
      source = FakeFeedSource(),
      backend = FakeBackend() {
    feed = PriceFeedCubit(
      PriceFeedService(source: source, clock: const SystemClock()),
    );
    portfolio = PortfolioCubit(
      reader: backend,
      mapper: const PulseApiExceptionMapper(),
    );
    flow = OrderFlowBloc(
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
  }

  final Instrument instrument;
  final ScriptedPlacer placer;
  final InMemoryPendingOrderStore store;
  final FakeFeedSource source;
  final FakeBackend backend;
  late final PriceFeedCubit feed;
  late final PortfolioCubit portfolio;
  late final OrderFlowBloc flow;

  Widget widget() {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: feed),
        BlocProvider.value(value: portfolio),
      ],
      child: PulseApp(
        home: TicketPage(
          instrument: instrument,
          orderFlow: flow,
          resolver: const DefaultErrorMessageResolver(),
        ),
      ),
    );
  }

  Future<void> close() async {
    await feed.close();
    await portfolio.close();
    await flow.close();
  }
}

_Ticket? _active;

void ticketTest(String name, Future<void> Function(WidgetTester tester) body) {
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

Future<_Ticket> _open(
  WidgetTester tester, {
  Instrument? instrument,
  List<Future<Order> Function(OrderRequest)>? steps,
  bool withPrice = true,
}) async {
  final ticket = _Ticket(instrument ?? testInstrument(), steps ?? [fills()]);
  _active = ticket;
  await tester.pumpWidget(ticket.widget());
  ticket.feed.setWatchlistSymbols([ticket.instrument.symbol]);
  await tester.pump();
  if (withPrice) {
    ticket.source.snapshot(
      {ticket.instrument.symbol: '100.00'},
      bid: '99.00',
      ask: '101.00',
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  return ticket;
}

Future<void> _type(WidgetTester tester, int fieldIndex, String text) async {
  await tester.enterText(find.byType(TextField).at(fieldIndex), text);
  await tester.pump();
}

bool _canPop(WidgetTester tester) =>
    (tester.widget(find.byWidgetPredicate((w) => w is PopScope)) as PopScope)
        .canPop;

Finder get _submit => find.widgetWithText(FilledButton, _l10n.submitOrder);

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton).last);
  await tester.tap(find.byType(FilledButton).last);
  await tester.pump();
}

void main() {
  group('validation (Must #3)', () {
    ticketTest('submitting empty input shows the error and sends nothing', (
      tester,
    ) async {
      final t = await _open(tester);

      await _tapSubmit(tester);

      expect(find.text(_l10n.validationRequired), findsOneWidget);
      expect(t.placer.sent, isEmpty);
    });

    ticketTest('quantity off the lot grid is explained with the step', (
      tester,
    ) async {
      await _open(tester);

      await _type(tester, 0, '1.5');

      expect(find.text(_l10n.validationNotMultipleOfLot('1')), findsOneWidget);
    });

    ticketTest('a comma cannot even be typed (ambiguous for money)', (
      tester,
    ) async {
      await _open(tester);

      await _type(tester, 0, '1,5');

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '15');
    });

    ticketTest('persian digits are accepted and priced', (tester) async {
      await _open(tester);

      await _type(tester, 0, '۱۰');

      expect(find.text('1,010.00 USD'), findsOneWidget);
    });

    ticketTest('limit orders show a price field validated by tick size', (
      tester,
    ) async {
      final t = await _open(tester);
      await _type(tester, 0, '10');

      await tester.tap(find.text(_l10n.typeLimit));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));
      await _type(tester, 1, '95.005');

      expect(
        find.text(_l10n.validationNotMultipleOfTick('0.01')),
        findsOneWidget,
      );

      await _type(tester, 1, '95.50');
      await _tapSubmit(tester);
      await tester.pump();

      expect(t.placer.sent.single.type, OrderType.limit);
      expect(t.placer.sent.single.limitPrice, Decimal.parse('95.50'));
    });

    ticketTest('the estimate follows side and shows its basis', (tester) async {
      await _open(tester);
      await _type(tester, 0, '10');

      expect(find.text('1,010.00 USD'), findsOneWidget);
      expect(find.text(_l10n.costBasisAsk), findsOneWidget);

      await tester.tap(find.text(_l10n.sideSell));
      await tester.pump();

      expect(find.text('990.00 USD'), findsOneWidget);
      expect(find.text(_l10n.costBasisBid), findsOneWidget);
    });
  });

  group('order safety (Must #4)', () {
    ticketTest('a fill is shown clearly and the account is refreshed', (
      tester,
    ) async {
      final t = await _open(tester);
      await _type(tester, 0, '10');
      final loadsBefore = t.backend.accountLoads;

      await _tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
      expect(t.placer.sent, hasLength(1));
      expect(t.backend.accountLoads, greaterThan(loadsBefore));
    });

    ticketTest(
      'while pending: button busy, fields locked, back blocked, one request',
      (tester) async {
        final gate = Completer<Order>();
        final t = await _open(tester, steps: [(_) => gate.future]);
        await _type(tester, 0, '10');

        await _tapSubmit(tester);
        await _tapSubmit(tester);
        await _tapSubmit(tester);
        await tester.pump();

        expect(t.placer.sent, hasLength(1), reason: 'double tap sends once');
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text(_l10n.orderSending), findsWidgets);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse,
        );
        expect(_canPop(tester), isFalse);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
          isNull,
        );

        gate.complete(testOrder(t.placer.sent.single));
        await tester.pump();
        await tester.pump();

        expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
        expect(_canPop(tester), isTrue);
      },
    );

    ticketTest(
      'a timeout is never shown as failure: it resolves with the same id',
      (tester) async {
        final t = await _open(
          tester,
          steps: [throwsAs(const RequestTimeoutException()), fills()],
        );
        await _type(tester, 0, '10');

        await _tapSubmit(tester);
        await tester.pump();
        await tester.pump();

        expect(find.text(_l10n.orderResolving), findsOneWidget);
        expect(find.text(_l10n.orderRejectedTitle), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
        expect(t.placer.sent.map((r) => r.clientOrderId).toSet(), {'ticket-1'});
      },
    );

    ticketTest(
      'unresolved: form stays locked until the user asks to check again',
      (tester) async {
        final t = await _open(
          tester,
          steps: [
            throwsAs(const RequestTimeoutException()),
            throwsAs(const RequestTimeoutException()),
            throwsAs(const RequestTimeoutException()),
            fills(),
          ],
        );
        await _type(tester, 0, '10');

        await _tapSubmit(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        expect(find.text(_l10n.orderUnresolvedTitle), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse,
        );
        expect(_submit, findsNothing);

        await tester.tap(find.text(_l10n.actionCheckOrderStatus));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
        expect(t.placer.sent.map((r) => r.clientOrderId).toSet(), {'ticket-1'});
      },
    );

    ticketTest('a rejection explains why and allows a corrected retry', (
      tester,
    ) async {
      final t = await _open(
        tester,
        steps: [
          throwsAs(const BusinessRuleException(code: 'INSUFFICIENT_FUNDS')),
          fills(),
        ],
      );
      await _type(tester, 0, '10');

      await _tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.orderRejectedTitle), findsOneWidget);
      expect(find.text(_l10n.errorInsufficientFunds), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isTrue,
      );

      await _type(tester, 0, '5');
      expect(find.text(_l10n.orderRejectedTitle), findsNothing);
      await _tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.orderFilledTitle), findsOneWidget);
      expect(
        t.placer.sent.map((r) => r.clientOrderId).toList(),
        ['ticket-1', 'ticket-2'],
        reason: 'a new attempt uses a NEW id',
      );
    });

    ticketTest('if the attempt cannot be saved nothing is sent', (
      tester,
    ) async {
      final t = await _open(tester);
      t.store.saveError = const StorageException();
      await _type(tester, 0, '10');

      await _tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(t.placer.sent, isEmpty);
      expect(find.text(_l10n.errorStorage), findsOneWidget);
    });
  });

  group('market conditions', () {
    ticketTest('an offline feed blocks submission with an explanation', (
      tester,
    ) async {
      final t = await _open(tester);
      await _type(tester, 0, '10');

      await tester.pump(const Duration(seconds: 16));

      expect(find.text(_l10n.ticketOfflineBlocked), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      expect(t.placer.sent, isEmpty);
    });

    ticketTest('a stale feed only warns on the estimate', (tester) async {
      await _open(tester);
      await _type(tester, 0, '10');

      await tester.pump(const Duration(seconds: 7));

      expect(find.text(_l10n.estimateStaleNote), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
    });

    ticketTest('a halted instrument cannot be ordered', (tester) async {
      await _open(
        tester,
        instrument: testInstrument(symbol: 'HALT', tradable: false),
        withPrice: false,
      );
      await _type(tester, 0, '10');

      expect(find.text(_l10n.errorTradingHalted), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
    });

    ticketTest('without any price the estimate says so instead of guessing', (
      tester,
    ) async {
      await _open(tester, withPrice: false);
      await _type(tester, 0, '10');

      expect(find.text(_l10n.estimatedUnavailable), findsOneWidget);
    });
  });

  group('earlier unresolved order (ORD-07)', () {
    ticketTest('a pending order for the same symbol locks the ticket', (
      tester,
    ) async {
      final ticket = _Ticket(testInstrument(), [fills()]);
      _active = ticket;
      ticket.store.items['old'] = _pending();
      await tester.pumpWidget(ticket.widget());
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n.orderUnresolvedTitle), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    });
  });

  group('holding and unit', () {
    ticketTest('shows how much of the instrument the user holds', (
      tester,
    ) async {
      final ticket = await _open(tester);
      ticket.backend.account = Account(
        currency: 'USD',
        cash: Decimal.parse('1000'),
        positions: [Position(symbol: 'AAPL', quantity: Decimal.fromInt(7))],
      );
      await ticket.portfolio.load();
      await tester.pump();

      expect(find.text(_l10n.holdingLabel('7', _l10n.unitShare)), findsOne);
    });

    ticketTest('says so when nothing is held', (tester) async {
      final ticket = await _open(tester);
      await ticket.portfolio.load();
      await tester.pump();

      expect(find.text(_l10n.holdingNone), findsOneWidget);
    });

    ticketTest('the quantity label carries the unit of a coin', (tester) async {
      await _open(
        tester,
        instrument: Instrument(
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
        ),
      );

      expect(find.text('${_l10n.quantityLabel} (BTC)'), findsOneWidget);
    });
  });

  group('what the user can buy or sell', () {
    Future<_Ticket> openWithCash(
      WidgetTester tester, {
      List<Position> positions = const [],
    }) async {
      final ticket = await _open(tester);
      ticket.backend.account = Account(
        currency: 'USD',
        cash: Decimal.parse('1000'),
        positions: positions,
      );
      await ticket.portfolio.load();
      await tester.pump();
      return ticket;
    }

    ticketTest('buying shows the USD available and the most affordable', (
      tester,
    ) async {
      await openWithCash(tester);

      expect(find.text(_l10n.availableToBuy('1,000.00 USD')), findsOneWidget);
      // cash 1000 / ask 101 = 9 whole shares
      expect(
        find.text(_l10n.availableToBuyMax('9', _l10n.unitShare)),
        findsOneWidget,
      );
    });

    ticketTest('the max button fills the quantity field', (tester) async {
      await openWithCash(tester);

      await tester.tap(find.text(_l10n.actionMax));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '9',
      );
    });

    ticketTest('selling shows how much can be sold', (tester) async {
      await openWithCash(
        tester,
        positions: [Position(symbol: 'AAPL', quantity: Decimal.fromInt(7))],
      );

      await tester.tap(find.text(_l10n.sideSell));
      await tester.pump();

      expect(
        find.text(_l10n.availableToSell('7', _l10n.unitShare)),
        findsOneWidget,
      );
      expect(find.textContaining(_l10n.availableToBuy('')), findsNothing);
    });

    ticketTest('selling with nothing held says so and offers no max', (
      tester,
    ) async {
      await openWithCash(tester);

      await tester.tap(find.text(_l10n.sideSell));
      await tester.pump();

      expect(find.text(_l10n.availableToSellNone), findsOneWidget);
      expect(find.text(_l10n.actionMax), findsNothing);
    });
  });
}

PendingOrder _pending() => PendingOrder(
  request: testRequest(id: 'old'),
  createdAt: DateTime(2026),
  unresolved: true,
);
