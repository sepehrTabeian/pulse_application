import 'package:pulse/features/trading/domain/entities/pending_order.dart';

/// Durable record of orders whose outcome is not yet confirmed.
/// Throws `StorageException` when it cannot persist - callers MUST NOT send
/// the order in that case.
abstract interface class PendingOrderStore {
  Future<void> save(PendingOrder order);
  Future<void> remove(String clientOrderId);
  Future<List<PendingOrder>> loadAll();
}
