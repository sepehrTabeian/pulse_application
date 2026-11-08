import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryPendingOrderStore store;
  late ScriptedPlacer lookup;
  late OrderRecoveryCubit cubit;

  setUp(() {
    store = InMemoryPendingOrderStore();
    lookup = ScriptedPlacer([fills()]);
    cubit = OrderRecoveryCubit(
      ReconcilePendingOrders(lookup: lookup, store: store),
    );
  });
  tearDown(() => cubit.close());

  void add(String id) => store.items[id] = PendingOrder(
    request: testRequest(id: id),
    createdAt: DateTime(2026),
  );

  test('starts empty and stays empty with nothing pending', () async {
    await cubit.run();

    expect(cubit.state, isEmpty);
  });

  test('reports what the server answered', () async {
    add('a');
    add('b');
    lookup.onLookup = (id) async => id == 'a'
        ? testOrder(testRequest(id: id))
        : throw const NotFoundException(code: 'ORDER_NOT_FOUND');

    await cubit.run();

    expect(cubit.state.whereType<OrderRecovered>(), hasLength(1));
    expect(cubit.state.whereType<OrderNotExecuted>(), hasLength(1));
  });

  test(
    'orders that could not be checked are not reported (kept for later)',
    () async {
      add('a');
      lookup.onLookup = (_) async => throw const ServiceUnavailableException();

      await cubit.run();

      expect(cubit.state, isEmpty);
      expect(store.items, hasLength(1));
    },
  );

  test('dismiss removes only that item', () async {
    add('a');
    add('b');
    lookup.onLookup = (id) async => testOrder(testRequest(id: id));
    await cubit.run();
    final first = cubit.state.first;

    cubit.dismiss(first);

    expect(cubit.state, hasLength(1));
    expect(cubit.state, isNot(contains(first)));
  });
}
