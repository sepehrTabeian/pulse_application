import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';

sealed class SubmitOutcome {
  const SubmitOutcome();
}

/// The server confirmed the order is filled or resting.
class OrderConfirmed extends SubmitOutcome {
  const OrderConfirmed(this.order);

  final Order order;
}

/// The server definitively refused the order (nothing executed).
class OrderRejectedOutcome extends SubmitOutcome {
  const OrderRejectedOutcome(this.error);

  final ServerException error;
}

/// We still do not KNOW. The attempt stays persisted; never guessed.
class OrderUnresolved extends SubmitOutcome {
  const OrderUnresolved(this.request);

  final OrderRequest request;
}

/// Sends an order safely (ORD-02..06, ADR-0005).
///
/// 1. Persist the attempt first; if that fails, nothing is sent.
/// 2. Send. If the outcome is unknown (timeout, 503, unreadable, unknown
///    status) re-send the SAME payload with the SAME `clientOrderId`:
///    the server de-duplicates, so this can never execute twice.
/// 3. Only a server answer ends the flow. Retries exhausted => unresolved.
class SubmitOrder {
  SubmitOrder({
    required OrderPlacer placer,
    required PendingOrderStore store,
    required RetryPolicy backoff,
    Clock clock = const SystemClock(),
    this.maxAttempts = 6,
  }) : _placer = placer,
       _store = store,
       _backoff = backoff,
       _clock = clock;

  final OrderPlacer _placer;
  final PendingOrderStore _store;
  final RetryPolicy _backoff;
  final Clock _clock;
  final int maxAttempts;

  /// Throws `StorageException` (and sends nothing) if it cannot persist.
  Future<SubmitOutcome> call(
    OrderRequest request, {
    void Function(int attempt)? onResolving,
  }) async {
    final pending = PendingOrder(request: request, createdAt: _clock.now());
    await _store.save(pending);
    return _resolveLoop(pending, onResolving);
  }

  /// Manual "check status": same request/id again, no new attempt record.
  Future<SubmitOutcome> resolve(
    OrderRequest request, {
    void Function(int attempt)? onResolving,
  }) {
    final pending = PendingOrder(request: request, createdAt: _clock.now());
    return _resolveLoop(pending, onResolving);
  }

  Future<SubmitOutcome> _resolveLoop(
    PendingOrder pending,
    void Function(int attempt)? onResolving,
  ) async {
    final request = pending.request;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final step = await _tryOnce(request);
      if (step != null) {
        await _cleanup(request.clientOrderId);
        return step;
      }
      if (attempt < maxAttempts) {
        onResolving?.call(attempt);
        await Future<void>.delayed(_backoff.delayFor(attempt));
      }
    }
    await _markUnresolved(pending);
    return OrderUnresolved(request);
  }

  /// Returns a final outcome, or null when the result is still unknown.
  Future<SubmitOutcome?> _tryOnce(OrderRequest request) async {
    try {
      final order = await _placer.place(request);
      return order.status == OrderStatus.unknown ? null : OrderConfirmed(order);
    } on ServiceUnavailableException {
      return null;
    } on ServerException catch (e) {
      return OrderRejectedOutcome(e);
    } on AppException {
      // Timeout / unreadable response / other client error: outcome unknown.
      return null;
    }
  }

  Future<void> _cleanup(String clientOrderId) async {
    try {
      await _store.remove(clientOrderId);
    } on StorageException {
      // The record is reconciled at next start; the outcome is unaffected.
    }
  }

  Future<void> _markUnresolved(PendingOrder pending) async {
    try {
      await _store.save(pending.markUnresolved());
    } on StorageException {
      // Already persisted as pending; stays recoverable.
    }
  }
}
