import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/orders/data/rejected_order_log_impl.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:pulse/features/orders/presentation/pages/orders_page.dart';
import 'package:pulse/features/trading/data/order_repository_impl.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

import '../../support/fake_trading_remote_source.dart';
import '../../support/in_memory_kv_store.dart';

String _json(String id, String status, {String? limit}) =>
    '{"orderId":"$id","clientOrderId":"c-$id","symbol":"AAPL","side":"BUY",'
    '"type":"${limit == null ? 'MARKET' : 'LIMIT'}","quantity":"2",'
    '${limit == null ? '' : '"limitPrice":"$limit",'}'
    '"status":"$status","filledQuantity":"0"}';

String _list(List<String> orders) => '{"orders":[${orders.join(',')}]}';

class _Fake implements OrderHistoryReader, RejectedOrderLog, InstrumentCatalog {
  List<Order> served = [];
  List<Order> rejected = [];
  List<Instrument> catalog = [
    Instrument(
      symbol: 'AAPL',
      name: 'AAPL Inc',
      type: InstrumentType.stock,
      exchange: 'X',
      currency: 'USD',
      tickSize: Decimal.parse('0.01'),
      lotSize: Decimal.one,
      prevClose: Decimal.parse('100'),
      tradable: true,
      unit: 'share',
    ),
    Instrument(
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
  ];
  Object? loadError;
  Object? rejectedError;
  Object? catalogError;

  @override
  Future<List<Order>> getOrders() async {
    final e = loadError;
    if (e != null) throw e;
    return served;
  }

  @override
  Future<void> add(Order order) async => rejected = [order, ...rejected];

  @override
  Future<List<Order>> loadAll() async {
    final e = rejectedError;
    if (e != null) throw e;
    return rejected;
  }

  @override
  Future<List<Instrument>> getInstruments() async {
    final e = catalogError;
    if (e != null) throw e;
    return catalog;
  }
}

Order _order(
  String id,
  OrderStatus status, {
  String symbol = 'AAPL',
  String? reason,
  DateTime? at,
}) => Order(
  orderId: id,
  clientOrderId: 'c-$id',
  symbol: symbol,
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: Decimal.parse(symbol == 'AAPL' ? '2' : '0.5'),
  status: status,
  filledQuantity: Decimal.zero,
  rejectReason: reason,
  createdAt: at,
);

OrdersCubit _cubit(_Fake f) => OrdersCubit(
  reader: f,
  rejectedLog: f,
  catalog: f,
  mapper: const PulseApiExceptionMapper(),
);

void main() {
  group('repository', () {
    late FakeTradingRemoteSource source;
    late OrderRepositoryImpl repo;
    setUp(() {
      source = FakeTradingRemoteSource();
      repo = OrderRepositoryImpl(
        source: source,
        guard: RemoteCallGuard(
          mapper: const PulseApiExceptionMapper(),
          retryPolicy: RetryPolicy(
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 2),
          ),
        ),
      );
    });

    test('maps every known status and keeps the limit price', () async {
      source.onGetOrders = () async => _list([
        _json('1', 'FILLED'),
        _json('2', 'WORKING', limit: '1.50'),
        _json('3', 'PENDING'),
        _json('4', 'REJECTED'),
        _json('5', 'CANCELLED'),
        _json('6', 'SOMETHING_NEW'),
      ]);

      final orders = await repo.getOrders();

      expect(orders.map((o) => o.status), [
        OrderStatus.filled,
        OrderStatus.working,
        OrderStatus.pending,
        OrderStatus.rejected,
        OrderStatus.cancelled,
        OrderStatus.unknown,
      ]);
      expect(orders[1].limitPrice, Decimal.parse('1.50'));
    });

    test('one unreadable row does not hide the others', () async {
      source.onGetOrders = () async =>
          _list([_json('1', 'FILLED'), '{"orderId":"bad"}']);

      expect(await repo.getOrders(), hasLength(1));
    });

    test('a failing request surfaces as an app exception', () {
      source.onGetOrders = () async => throw const FormatException('x');

      expect(repo.getOrders(), throwsA(isA<AppException>()));
    });
  });

  group('rejected order log', () {
    test('keeps entries newest first and survives a restart', () async {
      final store = InMemoryKeyValueStore();
      final log = RejectedOrderLogImpl(store);
      await log.add(
        _order('a', OrderStatus.rejected, reason: 'INSUFFICIENT_FUNDS'),
      );
      await log.add(
        _order('b', OrderStatus.rejected, reason: 'TRADING_HALTED'),
      );

      final reopened = await RejectedOrderLogImpl(store).loadAll();

      expect(reopened.map((o) => o.clientOrderId), ['c-b', 'c-a']);
      expect(reopened.first.rejectReason, 'TRADING_HALTED');
      expect(reopened.first.status, OrderStatus.rejected);
    });

    test('is capped and a damaged entry is skipped', () async {
      final store = InMemoryKeyValueStore();
      await store.writeStringList(RejectedOrderLogImpl.storageKey, ['{bad']);
      final log = RejectedOrderLogImpl(store);

      for (var i = 0; i < RejectedOrderLog.maxEntries + 5; i++) {
        await log.add(_order('$i', OrderStatus.rejected, reason: 'X'));
      }

      expect(await log.loadAll(), hasLength(RejectedOrderLog.maxEntries));
    });
  });

  group('cubit', () {
    late _Fake fake;
    late OrdersCubit cubit;
    setUp(() {
      fake = _Fake()
        ..served = [
          _order('1', OrderStatus.filled, at: DateTime.utc(2026, 1, 1, 10)),
          _order('2', OrderStatus.working, at: DateTime.utc(2026, 1, 1, 9)),
          _order(
            '4',
            OrderStatus.filled,
            symbol: 'BTC-USD',
            at: DateTime.utc(2026, 1, 1, 8),
          ),
        ]
        ..rejected = [
          _order(
            '3',
            OrderStatus.rejected,
            reason: 'INSUFFICIENT_FUNDS',
            at: DateTime.utc(2026, 1, 1, 11),
          ),
        ];
      cubit = _cubit(fake);
    });
    tearDown(() => cubit.close());

    test('merges server orders with local rejections, newest first', () async {
      await cubit.load();

      expect(cubit.state.orders.map((o) => o.orderId), ['3', '1', '2', '4']);
    });

    test('counts per status and filters by status', () async {
      await cubit.load();
      cubit.setFilter(OrderFilter.filled);

      expect(cubit.state.count(OrderFilter.working), 1);
      expect(cubit.state.count(OrderFilter.pending), 0);
      expect(cubit.state.visible.map((o) => o.orderId), ['1', '4']);
    });

    test('separates stocks from crypto', () async {
      await cubit.load();

      cubit.setAssetClass(AssetClass.crypto);
      expect(cubit.state.visible.map((o) => o.symbol), ['BTC-USD']);

      cubit.setAssetClass(AssetClass.stock);
      expect(cubit.state.visible.map((o) => o.symbol).toSet(), {'AAPL'});
      expect(cubit.state.count(OrderFilter.all), 3);

      cubit.setAssetClass(null);
      expect(cubit.state.visible, hasLength(4));
    });

    test('a failed first load is a failure; retry recovers', () async {
      fake.loadError = const ServiceUnavailableException();
      await cubit.load();
      expect(cubit.state.status, OrdersStatus.failure);

      fake.loadError = null;
      await cubit.load();
      expect(cubit.state.status, OrdersStatus.ready);
    });

    test('a failed refresh keeps the old list and reports once', () async {
      await cubit.load();
      fake.loadError = const ServiceUnavailableException();

      await cubit.load();

      expect(cubit.state.status, OrdersStatus.ready);
      expect(cubit.state.orders, hasLength(4));
      expect(cubit.state.refreshError, isNotNull);
      cubit.clearRefreshError();
      expect(cubit.state.refreshError, isNull);
    });

    test('an unreadable local log or catalogue never hides orders', () async {
      fake
        ..rejectedError = const StorageException()
        ..catalogError = const ServiceUnavailableException();

      await cubit.load();

      expect(cubit.state.status, OrdersStatus.ready);
      expect(cubit.state.orders, hasLength(3));
    });
  });

  group('page', () {
    late _Fake fake;
    late OrdersCubit cubit;

    Future<void> pump(WidgetTester tester) async {
      cubit = _cubit(fake);
      await tester.pumpWidget(
        MaterialApp(
          theme: PulseTheme.light(),
          locale: const Locale('fa'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: BlocProvider.value(
            value: cubit,
            child: const OrdersPage(resolver: DefaultErrorMessageResolver()),
          ),
        ),
      );
      await cubit.load();
      await tester.pumpAndSettle();
    }

    setUp(() => fake = _Fake());
    tearDown(() => cubit.close());

    AppLocalizations l10n(WidgetTester t) =>
        AppLocalizations.of(t.element(find.byType(OrdersPage)));

    testWidgets('no orders shows the empty state', (tester) async {
      await pump(tester);

      expect(find.text(l10n(tester).ordersEmptyTitle), findsOneWidget);
    });

    testWidgets('a load failure shows retry that recovers', (tester) async {
      fake.loadError = const ServiceUnavailableException();
      await pump(tester);
      expect(find.text(l10n(tester).ordersLoadFailedTitle), findsOneWidget);

      fake.loadError = null;
      fake.served = [_order('1', OrderStatus.filled)];
      await tester.tap(find.text(l10n(tester).actionRetry));
      await tester.pumpAndSettle();

      expect(find.text('AAPL'), findsOneWidget);
    });

    testWidgets('cards say what happened in clear words', (tester) async {
      fake.served = [
        Order(
          orderId: '1',
          clientOrderId: 'c-1',
          symbol: 'AAPL',
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: Decimal.fromInt(2),
          status: OrderStatus.filled,
          filledQuantity: Decimal.fromInt(2),
          averagePrice: Decimal.parse('150.5'),
        ),
        _order('9', OrderStatus.working, symbol: 'BTC-USD'),
      ];
      fake.rejected = [
        _order('3', OrderStatus.rejected, reason: 'INSUFFICIENT_FUNDS'),
      ];
      await pump(tester);
      final t = l10n(tester);

      expect(
        find.text(t.orderQuantityLine('2', t.unitShare)),
        findsNWidgets(2),
      );
      expect(find.text(t.orderQuantityLine('0.5000', 'BTC')), findsOneWidget);
      expect(find.text(t.orderFilledAt('150.50 USD')), findsOneWidget);
      expect(find.text(t.errorInsufficientFunds), findsOneWidget);
      expect(find.text(t.orderStatusWorking), findsWidgets);
    });

    testWidgets('the status dropdown filters the list', (tester) async {
      fake.served = [
        _order('1', OrderStatus.filled),
        _order('2', OrderStatus.working),
      ];
      await pump(tester);
      final t = l10n(tester);

      await tester.tap(find.byKey(const ValueKey('status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${t.orderFilterWorking} (1)').last);
      await tester.pumpAndSettle();

      expect(find.text(t.orderStatusWorking), findsWidgets);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('an empty filter shows its own empty state', (tester) async {
      fake.served = [_order('1', OrderStatus.filled)];
      await pump(tester);

      cubit.setFilter(OrderFilter.cancelled);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).ordersEmptyFilteredTitle), findsOneWidget);
    });

    testWidgets('the asset dropdown separates crypto from stocks', (
      tester,
    ) async {
      fake.served = [
        _order('1', OrderStatus.filled),
        _order('2', OrderStatus.filled, symbol: 'BTC-USD'),
      ];
      await pump(tester);
      final t = l10n(tester);

      await tester.tap(find.byKey(const ValueKey('asset-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.assetCrypto).last);
      await tester.pumpAndSettle();

      expect(find.text('BTC-USD'), findsOneWidget);
      expect(find.text('AAPL'), findsNothing);
    });
  });
}
