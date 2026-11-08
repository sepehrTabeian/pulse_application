import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';

/// Runs ORD-07 at startup and exposes what the server told us about orders
/// that were unconfirmed when the app last closed. The user dismisses items.
class OrderRecoveryCubit extends Cubit<List<RecoveryResult>> {
  OrderRecoveryCubit(this._reconcile) : super(const <RecoveryResult>[]);

  final ReconcilePendingOrders _reconcile;

  Future<void> run() async {
    final results = await _reconcile();
    if (isClosed) return;
    // Items we could not check stay in the store and are retried next start;
    // only report what the server actually answered.
    emit([
      for (final r in results)
        if (r is! OrderCheckFailed) r,
    ]);
  }

  void dismiss(RecoveryResult result) {
    emit([
      for (final r in state)
        if (!identical(r, result)) r,
    ]);
  }
}
