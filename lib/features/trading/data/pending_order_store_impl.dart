import 'dart:async';
import 'dart:convert';

import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:pulse/features/trading/data/models/order_request_model.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';

/// Persists pending orders as hand-written JSON (ADR-0003). Writes are
/// serialised so concurrent save/remove can never lose an update.
class PendingOrderStoreImpl implements PendingOrderStore {
  PendingOrderStoreImpl(this._store);

  static const String storageKey = 'pending_orders_v1';

  final KeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> save(PendingOrder order) {
    return _serialized(() async {
      final all = await _readAll();
      all[order.request.clientOrderId] = order;
      await _writeAll(all);
    });
  }

  @override
  Future<void> remove(String clientOrderId) {
    return _serialized(() async {
      final all = await _readAll();
      if (all.remove(clientOrderId) != null) await _writeAll(all);
    });
  }

  @override
  Future<List<PendingOrder>> loadAll() {
    return _serialized(() async => (await _readAll()).values.toList());
  }

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

  Future<Map<String, PendingOrder>> _readAll() async {
    final raw = await _store.readStringList(storageKey);
    final result = <String, PendingOrder>{};
    for (final entry in raw) {
      final order = _decode(entry);
      if (order != null) result[order.request.clientOrderId] = order;
    }
    return result;
  }

  Future<void> _writeAll(Map<String, PendingOrder> all) {
    return _store.writeStringList(storageKey, [
      for (final order in all.values) _encode(order),
    ]);
  }

  static String _encode(PendingOrder order) {
    final request = jsonDecode(
      OrderRequestModel.fromEntity(order.request).toJsonString(),
    );
    return jsonEncode({
      'request': request,
      'createdAt': order.createdAt.toUtc().toIso8601String(),
      'unresolved': order.unresolved,
    });
  }

  /// Tolerant decode: a corrupt entry is dropped, never thrown.
  static PendingOrder? _decode(String raw) {
    try {
      final json = JsonReader.parse(raw);
      final request = JsonReader.tryFrom(_requestObject(raw));
      if (request == null) return null;
      final side = switch (request.string('side')?.toUpperCase()) {
        'BUY' => OrderSide.buy,
        'SELL' => OrderSide.sell,
        _ => null,
      };
      final type = switch (request.string('type')?.toUpperCase()) {
        'MARKET' => OrderType.market,
        'LIMIT' => OrderType.limit,
        _ => null,
      };
      final id = request.string('clientOrderId')?.trim();
      final symbol = request.string('symbol')?.trim();
      final quantity = request.decimal('quantity');
      final limit = request.decimal('limitPrice');
      final createdAt = json.dateTime('createdAt');
      if (side == null ||
          type == null ||
          id == null ||
          id.isEmpty ||
          symbol == null ||
          symbol.isEmpty ||
          quantity == null ||
          createdAt == null ||
          (type == OrderType.limit && limit == null)) {
        return null;
      }
      return PendingOrder(
        request: OrderRequest(
          clientOrderId: id,
          symbol: symbol,
          side: side,
          type: type,
          quantity: quantity,
          limitPrice: type == OrderType.limit ? limit : null,
        ),
        createdAt: createdAt,
        unresolved: json.boolean('unresolved') ?? false,
      );
    } on ParsingException {
      return null;
    }
  }

  static Object? _requestObject(String raw) {
    final decoded = jsonDecode(raw);
    return decoded is Map<Object?, Object?> ? decoded['request'] : null;
  }
}
