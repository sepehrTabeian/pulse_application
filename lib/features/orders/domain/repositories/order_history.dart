import 'package:pulse/features/trading/domain/entities/order.dart';

/// All orders of the account as the server reports them, newest first.
abstract interface class OrderHistoryReader {
  Future<List<Order>> getOrders();
}

/// Orders the server refused. The server does not list them, so the app keeps
/// its own record (last [maxEntries]) to show them in the history.
abstract interface class RejectedOrderLog {
  static const int maxEntries = 50;

  Future<void> add(Order rejected);
  Future<List<Order>> loadAll();
}
