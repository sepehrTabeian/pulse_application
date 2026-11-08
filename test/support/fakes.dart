import 'package:decimal/decimal.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';

Instrument testInstrument({
  String symbol = 'AAPL',
  String tick = '0.01',
  String lot = '1',
  bool tradable = true,
  String? prevClose = '100',
}) => Instrument(
  symbol: symbol,
  name: '$symbol Inc',
  type: InstrumentType.stock,
  exchange: 'X',
  currency: 'USD',
  tickSize: Decimal.parse(tick),
  lotSize: Decimal.parse(lot),
  prevClose: prevClose == null ? null : Decimal.parse(prevClose),
  tradable: tradable,
  unit: 'share',
);

OrderRequest testRequest({
  String id = 'c1',
  String symbol = 'AAPL',
  OrderSide side = OrderSide.buy,
  OrderType type = OrderType.market,
  String quantity = '10',
  String? limitPrice,
}) => OrderRequest(
  clientOrderId: id,
  symbol: symbol,
  side: side,
  type: type,
  quantity: Decimal.parse(quantity),
  limitPrice: limitPrice == null ? null : Decimal.parse(limitPrice),
);

Order testOrder(OrderRequest r, {OrderStatus status = OrderStatus.filled}) =>
    Order(
      orderId: 'o-${r.clientOrderId}',
      clientOrderId: r.clientOrderId,
      symbol: r.symbol,
      side: r.side,
      type: r.type,
      quantity: r.quantity,
      status: status,
      filledQuantity: status == OrderStatus.filled ? r.quantity : Decimal.zero,
    );

/// Scripted [OrderPlacer]: each call consumes the next step.
class ScriptedPlacer implements OrderPlacer, OrderLookup {
  ScriptedPlacer(this.steps);

  /// Each step either returns an [Order] or throws.
  final List<Future<Order> Function(OrderRequest)> steps;
  final List<OrderRequest> sent = [];
  int lookups = 0;
  Future<Order> Function(String id)? onLookup;

  @override
  Future<Order> place(OrderRequest request) {
    sent.add(request);
    final index = sent.length - 1;
    final step = index < steps.length ? steps[index] : steps.last;
    return step(request);
  }

  @override
  Future<Order> getByClientOrderId(String clientOrderId) {
    lookups++;
    final handler = onLookup;
    if (handler == null) throw StateError('lookup not scripted');
    return handler(clientOrderId);
  }
}

Future<Order> Function(OrderRequest) fills([
  OrderStatus status = OrderStatus.filled,
]) =>
    (r) async => testOrder(r, status: status);

Future<Order> Function(OrderRequest) throwsAs(AppException e) =>
    (_) async => throw e;

class InMemoryPendingOrderStore implements PendingOrderStore {
  final Map<String, PendingOrder> items = {};
  Object? saveError;
  Object? removeError;
  final List<String> log = [];

  @override
  Future<void> save(PendingOrder order) async {
    log.add('save:${order.request.clientOrderId}:${order.unresolved}');
    final error = saveError;
    if (error != null) throw error;
    items[order.request.clientOrderId] = order;
  }

  @override
  Future<void> remove(String clientOrderId) async {
    log.add('remove:$clientOrderId');
    final error = removeError;
    if (error != null) throw error;
    items.remove(clientOrderId);
  }

  @override
  Future<List<PendingOrder>> loadAll() async => items.values.toList();
}
