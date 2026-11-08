import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/trading/data/models/order_model.dart';
import 'package:pulse/features/trading/data/models/order_request_model.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';

class OrderRepositoryImpl
    implements OrderPlacer, OrderLookup, OrderHistoryReader {
  OrderRepositoryImpl({
    required TradingRemoteSource source,
    required RemoteCallGuard guard,
  }) : _source = source,
       _guard = guard;

  final TradingRemoteSource _source;
  final RemoteCallGuard _guard;

  /// Exactly one network attempt. Anything we cannot read back with
  /// certainty is reported as "outcome unknown" (ADR-0005).
  @override
  Future<Order> place(OrderRequest request) async {
    final json = OrderRequestModel.fromEntity(request).toJsonString();
    final body = await _guard.once(() => _source.placeOrder(json));
    try {
      final order = OrderModel.fromJson(JsonReader.parse(body)).toEntity();
      if (order.clientOrderId != request.clientOrderId) {
        throw const ParsingException(
          field: 'clientOrderId',
          expectedType: 'echo of the request id',
          actualType: 'different id',
        );
      }
      return order;
    } on ParsingException catch (e, st) {
      throw RequestTimeoutException(cause: e, stackTrace: st);
    }
  }

  @override
  Future<Order> getByClientOrderId(String clientOrderId) async {
    final id = clientOrderId.trim();
    if (id.isEmpty) {
      throw const ValidationException(field: 'clientOrderId', rule: 'required');
    }
    final body = await _guard.retrying(() => _source.getOrder(id));
    return OrderModel.fromJson(JsonReader.parse(body)).toEntity();
  }

  @override
  Future<List<Order>> getOrders() async {
    final body = await _guard.retrying(_source.getOrders);
    final items =
        JsonReader.parse(body).objects('orders') ??
        (throw const ParsingException(field: 'orders', expectedType: 'list'));
    final orders = <Order>[];
    for (final item in items) {
      try {
        orders.add(OrderModel.fromJson(item).toEntity());
      } on ParsingException {
        // One unreadable row must not hide the rest of the history.
        continue;
      }
    }
    return orders;
  }
}
