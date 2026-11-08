import 'package:pulse/features/trading/domain/entities/order.dart';

/// Looks an order up by its idempotency key. Throws `NotFoundException`
/// (ORDER_NOT_FOUND) when the server has no such order.
abstract interface class OrderLookup {
  Future<Order> getByClientOrderId(String clientOrderId);
}
