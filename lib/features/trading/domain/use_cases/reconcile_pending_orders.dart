import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';

sealed class RecoveryResult {
  const RecoveryResult(this.pending);

  final PendingOrder pending;
}

/// The server confirmed what happened to the order.
class OrderRecovered extends RecoveryResult {
  const OrderRecovered(super.pending, this.order);

  final Order order;
}

/// The server answered ORDER_NOT_FOUND: it was not executed (Q4).
class OrderNotExecuted extends RecoveryResult {
  const OrderNotExecuted(super.pending);
}

/// The server knows the order but its status is not understood.
class OrderStillUnresolved extends RecoveryResult {
  const OrderStillUnresolved(super.pending);
}

/// Could not ask the server now; the record is kept for later.
class OrderCheckFailed extends RecoveryResult {
  const OrderCheckFailed(super.pending, this.error);

  final AppException error;
}

/// ORD-07: after a restart, ask the server about every unconfirmed attempt.
/// It only LOOKS UP; it never re-sends an order on its own (Q5).
class ReconcilePendingOrders {
  const ReconcilePendingOrders({
    required OrderLookup lookup,
    required PendingOrderStore store,
  }) : _lookup = lookup,
       _store = store;

  final OrderLookup _lookup;
  final PendingOrderStore _store;

  Future<List<RecoveryResult>> call() async {
    final List<PendingOrder> pending;
    try {
      pending = await _store.loadAll();
    } on StorageException {
      return const <RecoveryResult>[];
    }
    final results = <RecoveryResult>[];
    for (final item in pending) {
      results.add(await _reconcile(item));
    }
    return List.unmodifiable(results);
  }

  Future<RecoveryResult> _reconcile(PendingOrder item) async {
    try {
      final order = await _lookup.getByClientOrderId(
        item.request.clientOrderId,
      );
      if (order.status == OrderStatus.unknown) {
        return OrderStillUnresolved(item);
      }
      await _forget(item);
      return OrderRecovered(item, order);
    } on NotFoundException {
      await _forget(item);
      return OrderNotExecuted(item);
    } on AppException catch (e) {
      return OrderCheckFailed(item, e);
    }
  }

  Future<void> _forget(PendingOrder item) async {
    try {
      await _store.remove(item.request.clientOrderId);
    } on StorageException {
      // Looked up again at the next start; harmless.
    }
  }
}
