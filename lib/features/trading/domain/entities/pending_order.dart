import 'package:equatable/equatable.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

/// An order attempt persisted BEFORE it is sent (ADR-0003, ORD-03).
class PendingOrder extends Equatable {
  const PendingOrder({
    required this.request,
    required this.createdAt,
    this.unresolved = false,
  });

  final OrderRequest request;
  final DateTime createdAt;

  /// True once automatic resolution gave up; still needs the server's answer.
  final bool unresolved;

  PendingOrder markUnresolved() =>
      PendingOrder(request: request, createdAt: createdAt, unresolved: true);

  @override
  List<Object?> get props => [request, createdAt, unresolved];
}
