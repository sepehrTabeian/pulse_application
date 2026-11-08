import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

/// Wire shape of an order response.
class OrderModel {
  const OrderModel({
    this.orderId,
    this.clientOrderId,
    this.symbol,
    this.side,
    this.type,
    this.quantity,
    this.status,
    this.filledQuantity,
    this.averagePrice,
    this.createdAt,
    this.rejectReason,
    this.limitPrice,
  });

  factory OrderModel.fromJson(JsonReader json) {
    return OrderModel(
      orderId: json.string('orderId'),
      clientOrderId: json.string('clientOrderId'),
      symbol: json.string('symbol'),
      side: json.string('side'),
      type: json.string('type'),
      quantity: json.decimal('quantity'),
      status: json.string('status'),
      filledQuantity: json.decimal('filledQuantity'),
      averagePrice: json.decimal('averagePrice'),
      createdAt: json.dateTime('createdAt'),
      rejectReason: json.string('rejectReason'),
      limitPrice: json.decimal('limitPrice'),
    );
  }

  final String? orderId;
  final String? clientOrderId;
  final String? symbol;
  final String? side;
  final String? type;
  final Decimal? quantity;
  final String? status;
  final Decimal? filledQuantity;
  final Decimal? averagePrice;
  final DateTime? createdAt;
  final String? rejectReason;
  final Decimal? limitPrice;

  /// Throws [ParsingException] if identity, side, type or quantity cannot be
  /// determined. An unrecognised status becomes [OrderStatus.unknown].
  Order toEntity() {
    return Order(
      orderId: orderId?.trim() ?? '',
      clientOrderId: _required(clientOrderId, 'clientOrderId'),
      symbol: _required(symbol, 'symbol'),
      side: _side(side),
      type: _type(type),
      quantity: requireValue<Decimal>(quantity, 'quantity', 'decimal'),
      status: _status(status),
      filledQuantity: filledQuantity ?? Decimal.zero,
      averagePrice: averagePrice,
      createdAt: createdAt,
      rejectReason: rejectReason?.trim(),
      limitPrice: limitPrice,
    );
  }

  static String _required(String? value, String field) {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      throw ParsingException(field: field, expectedType: 'string');
    }
    return v;
  }

  static OrderSide _side(String? raw) {
    return switch (raw?.trim().toUpperCase()) {
      'BUY' => OrderSide.buy,
      'SELL' => OrderSide.sell,
      _ => throw ParsingException(
        field: 'side',
        expectedType: 'BUY|SELL',
        actualType: raw,
      ),
    };
  }

  static OrderType _type(String? raw) {
    return switch (raw?.trim().toUpperCase()) {
      'MARKET' => OrderType.market,
      'LIMIT' => OrderType.limit,
      _ => throw ParsingException(
        field: 'type',
        expectedType: 'MARKET|LIMIT',
        actualType: raw,
      ),
    };
  }

  static OrderStatus _status(String? raw) {
    return switch (raw?.trim().toUpperCase()) {
      'FILLED' => OrderStatus.filled,
      'WORKING' => OrderStatus.working,
      'PENDING' => OrderStatus.pending,
      'REJECTED' => OrderStatus.rejected,
      'CANCELLED' || 'CANCELED' => OrderStatus.cancelled,
      _ => OrderStatus.unknown,
    };
  }
}
