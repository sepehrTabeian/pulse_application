import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

/// Keeps the orders the server refused, newest first, as hand-written JSON.
/// Writes are serialised so two rejections can never lose each other.
class RejectedOrderLogImpl implements RejectedOrderLog {
  RejectedOrderLogImpl(this._store);

  static const String storageKey = 'rejected_orders_v1';

  final KeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> add(Order rejected) => _serialized(() async {
    final all = await _read();
    final next = [
      rejected,
      ...all.where((o) => o.clientOrderId != rejected.clientOrderId),
    ].take(RejectedOrderLog.maxEntries).toList();
    await _store.writeStringList(storageKey, next.map(_encode).toList());
  });

  @override
  Future<List<Order>> loadAll() => _serialized(_read);

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<List<Order>> _read() async {
    final raw = await _store.readStringList(storageKey);
    return [for (final entry in raw) ?_decode(entry)];
  }

  static String _encode(Order o) => jsonEncode({
    'orderId': o.orderId,
    'clientOrderId': o.clientOrderId,
    'symbol': o.symbol,
    'side': o.side.name,
    'type': o.type.name,
    'quantity': o.quantity.toString(),
    'limitPrice': o.limitPrice?.toString(),
    'reason': o.rejectReason,
    'at': o.createdAt?.toIso8601String(),
  });

  /// A damaged entry is skipped instead of hiding the whole history.
  static Order? _decode(String raw) {
    try {
      final json = JsonReader.parse(raw);
      return Order(
        orderId: json.string('orderId') ?? '',
        clientOrderId: json.requireString('clientOrderId'),
        symbol: json.requireString('symbol'),
        side: OrderSide.values.byName(json.requireString('side')),
        type: OrderType.values.byName(json.requireString('type')),
        quantity: json.requireDecimal('quantity'),
        status: OrderStatus.rejected,
        filledQuantity: Decimal.zero,
        limitPrice: json.decimal('limitPrice'),
        rejectReason: json.string('reason'),
        createdAt: json.dateTime('at'),
      );
    } on Object {
      return null;
    }
  }
}
