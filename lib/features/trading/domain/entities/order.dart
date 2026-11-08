import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum OrderSide { buy, sell }

enum OrderType { market, limit }

/// `unknown` = the server said something we do not understand. It is NEVER
/// treated as filled/working: the outcome is unresolved (ADR-0005).
enum OrderStatus {
  /// Under review by the server.
  pending,

  /// Accepted and resting in the queue (e.g. a limit order).
  working,
  filled,
  rejected,
  cancelled,
  unknown,
}

/// What the user asks for. A LIMIT order must carry [limitPrice].
class OrderRequest extends Equatable {
  const OrderRequest({
    required this.clientOrderId,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    this.limitPrice,
  }) : assert(
         type != OrderType.limit || limitPrice != null,
         'LIMIT orders need a limitPrice',
       );

  /// Idempotency key.
  final String clientOrderId;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final Decimal quantity;
  final Decimal? limitPrice;

  @override
  List<Object?> get props => [
    clientOrderId,
    symbol,
    side,
    type,
    quantity,
    limitPrice,
  ];
}

/// The server's confirmed answer for an order.
class Order extends Equatable {
  const Order({
    required this.orderId,
    required this.clientOrderId,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    required this.status,
    required this.filledQuantity,
    this.averagePrice,
    this.createdAt,
    this.rejectReason,
    this.limitPrice,
  });

  final String orderId;
  final String clientOrderId;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final Decimal quantity;
  final OrderStatus status;
  final Decimal filledQuantity;
  final Decimal? averagePrice;
  final DateTime? createdAt;

  final Decimal? limitPrice;

  /// Server error code when [status] is rejected (e.g. INSUFFICIENT_FUNDS).
  final String? rejectReason;

  @override
  List<Object?> get props => [
    orderId,
    clientOrderId,
    symbol,
    side,
    type,
    quantity,
    status,
    filledQuantity,
    averagePrice,
    createdAt,
    rejectReason,
    limitPrice,
  ];
}
