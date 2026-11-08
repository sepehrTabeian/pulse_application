import 'package:pulse/features/trading/domain/entities/order.dart';

/// Sends ONE order request. It never retries by itself and never guesses.
///
/// An unconfirmed outcome (timeout, unreadable response, mismatching id) is
/// reported as `RequestTimeoutException` = "outcome unknown", NOT as failure.
/// Definite rejections are `ServerException` subtypes.
abstract interface class OrderPlacer {
  Future<Order> place(OrderRequest request);
}
