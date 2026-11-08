import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/data/pending_order_store_impl.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';

import '../../../support/fakes.dart';
import '../../../support/in_memory_kv_store.dart';

PendingOrder _pending(
  String id, {
  OrderRequest? request,
  bool unresolved = false,
}) => PendingOrder(
  request: request ?? testRequest(id: id),
  createdAt: DateTime.utc(2026, 11, 8, 12),
  unresolved: unresolved,
);

void main() {
  late InMemoryKeyValueStore kv;
  late PendingOrderStoreImpl store;

  setUp(() {
    kv = InMemoryKeyValueStore();
    store = PendingOrderStoreImpl(kv);
  });

  test('starts empty', () async {
    expect(await store.loadAll(), isEmpty);
  });

  test('round-trips a market order', () async {
    await store.save(_pending('a'));

    final all = await store.loadAll();

    expect(all, [_pending('a')]);
  });

  test('round-trips a limit order keeping exact decimals', () async {
    final request = testRequest(
      id: 'l',
      type: OrderType.limit,
      side: OrderSide.sell,
      quantity: '0.0005',
      limitPrice: '67250.01',
    );
    await store.save(_pending('l', request: request, unresolved: true));

    final loaded = (await store.loadAll()).single;

    expect(loaded.request.quantity, Decimal.parse('0.0005'));
    expect(loaded.request.limitPrice, Decimal.parse('67250.01'));
    expect(loaded.request.side, OrderSide.sell);
    expect(loaded.unresolved, isTrue);
  });

  test(
    'saving the same id replaces the record instead of duplicating',
    () async {
      await store.save(_pending('a'));
      await store.save(_pending('a', unresolved: true));

      final all = await store.loadAll();

      expect(all, hasLength(1));
      expect(all.single.unresolved, isTrue);
    },
  );

  test('remove deletes one record; removing a missing id is a no-op', () async {
    await store.save(_pending('a'));
    await store.save(_pending('b'));

    await store.remove('a');
    await store.remove('does-not-exist');

    expect((await store.loadAll()).map((p) => p.request.clientOrderId), ['b']);
  });

  test('concurrent saves never lose an update', () async {
    await Future.wait([
      for (var i = 0; i < 25; i++) store.save(_pending('id-$i')),
    ]);

    expect(await store.loadAll(), hasLength(25));
  });

  test('concurrent save and remove stay consistent', () async {
    await store.save(_pending('keep'));
    await Future.wait([
      store.save(_pending('new')),
      store.remove('keep'),
      store.save(_pending('other')),
    ]);

    final ids = (await store.loadAll()).map((p) => p.request.clientOrderId);

    expect(ids, unorderedEquals(['new', 'other']));
  });

  test('corrupt or invalid entries are dropped, valid ones survive', () async {
    await store.save(_pending('good'));
    kv.data[PendingOrderStoreImpl.storageKey]!.addAll([
      'not json',
      '{}',
      '[]',
      '{"request":null}',
      '{"request":{"clientOrderId":"x","symbol":"A","side":"HOLD","type":"MARKET","quantity":"1"},"createdAt":"2026-01-01T00:00:00Z"}',
      '{"request":{"clientOrderId":"y","symbol":"A","side":"BUY","type":"LIMIT","quantity":"1"},"createdAt":"2026-01-01T00:00:00Z"}',
      '{"request":{"clientOrderId":"z","symbol":"A","side":"BUY","type":"MARKET","quantity":"abc"},"createdAt":"2026-01-01T00:00:00Z"}',
    ]);

    final all = await store.loadAll();

    expect(all.map((p) => p.request.clientOrderId), ['good']);
  });

  test('a failed write surfaces StorageException', () async {
    kv.failWrites = true;

    await expectLater(
      store.save(_pending('a')),
      throwsA(isA<StorageException>()),
    );
  });

  test('a failed read surfaces StorageException', () async {
    kv.failReads = true;

    await expectLater(store.loadAll(), throwsA(isA<StorageException>()));
  });

  test(
    'after a failure the store keeps working (queue is not poisoned)',
    () async {
      kv.failWrites = true;
      await expectLater(store.save(_pending('a')), throwsA(anything));
      kv.failWrites = false;

      await store.save(_pending('b'));

      expect((await store.loadAll()).single.request.clientOrderId, 'b');
    },
  );
}
