import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryPendingOrderStore store;
  late ScriptedPlacer lookup;
  late ReconcilePendingOrders reconcile;

  PendingOrder add(String id) {
    final p = PendingOrder(
      request: testRequest(id: id),
      createdAt: DateTime(2026),
    );
    store.items[id] = p;
    return p;
  }

  setUp(() {
    store = InMemoryPendingOrderStore();
    lookup = ScriptedPlacer([fills()]);
    reconcile = ReconcilePendingOrders(lookup: lookup, store: store);
  });

  test('nothing pending means nothing to do', () async {
    expect(await reconcile(), isEmpty);
    expect(lookup.lookups, 0);
  });

  test('a found order is recovered and the record removed', () async {
    add('a');
    lookup.onLookup = (id) async => testOrder(testRequest(id: id));

    final results = await reconcile();

    expect(results.single, isA<OrderRecovered>());
    expect(store.items, isEmpty);
  });

  test('a resting (working) order is recovered too', () async {
    add('a');
    lookup.onLookup = (id) async =>
        testOrder(testRequest(id: id), status: OrderStatus.working);

    final results = await reconcile();

    expect(
      (results.single as OrderRecovered).order.status,
      OrderStatus.working,
    );
  });

  test(
    'ORDER_NOT_FOUND means not executed and clears the record (Q4)',
    () async {
      add('a');
      lookup.onLookup = (_) async =>
          throw const NotFoundException(code: 'ORDER_NOT_FOUND');

      final results = await reconcile();

      expect(results.single, isA<OrderNotExecuted>());
      expect(store.items, isEmpty);
    },
  );

  test('a transient failure keeps the record for next time', () async {
    add('a');
    lookup.onLookup = (_) async => throw const ServiceUnavailableException();

    final results = await reconcile();

    expect(results.single, isA<OrderCheckFailed>());
    expect(store.items, hasLength(1));
  });

  test(
    'an unrecognised server status keeps the record (never guessed)',
    () async {
      add('a');
      lookup.onLookup = (id) async =>
          testOrder(testRequest(id: id), status: OrderStatus.unknown);

      final results = await reconcile();

      expect(results.single, isA<OrderStillUnresolved>());
      expect(store.items, hasLength(1));
    },
  );

  test('it only looks up; it never re-sends an order', () async {
    add('a');
    lookup.onLookup = (_) async =>
        throw const NotFoundException(code: 'ORDER_NOT_FOUND');

    await reconcile();

    expect(lookup.sent, isEmpty);
  });

  test('one failure does not stop the other orders', () async {
    add('a');
    add('b');
    lookup.onLookup = (id) async {
      if (id == 'a') throw const ServiceUnavailableException();
      return testOrder(testRequest(id: id));
    };

    final results = await reconcile();

    expect(results, hasLength(2));
    expect(results.whereType<OrderCheckFailed>(), hasLength(1));
    expect(results.whereType<OrderRecovered>(), hasLength(1));
    expect(store.items.keys, ['a']);
  });

  test('an unreadable store yields no results instead of crashing', () async {
    final broken = _BrokenStore();
    final r = ReconcilePendingOrders(lookup: lookup, store: broken);

    expect(await r(), isEmpty);
  });

  test('a failing cleanup still reports the recovered order', () async {
    add('a');
    store.removeError = const StorageException();
    lookup.onLookup = (id) async => testOrder(testRequest(id: id));

    final results = await reconcile();

    expect(results.single, isA<OrderRecovered>());
  });
}

class _BrokenStore extends InMemoryPendingOrderStore {
  @override
  Future<List<PendingOrder>> loadAll() async => throw const StorageException();
}
