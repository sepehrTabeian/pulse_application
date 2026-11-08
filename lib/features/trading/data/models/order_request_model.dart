import 'dart:convert';

import 'package:pulse/features/trading/domain/entities/order.dart';

/// Wire shape of an order request. Amounts are decimal STRINGS (never
/// JSON numbers) and are never routed through `double`.
class OrderRequestModel {
  const OrderRequestModel._(this._fields);

  factory OrderRequestModel.fromEntity(OrderRequest request) {
    final limitPrice = request.limitPrice;
    return OrderRequestModel._({
      'clientOrderId': request.clientOrderId,
      'symbol': request.symbol,
      'side': request.side == OrderSide.buy ? 'BUY' : 'SELL',
      'type': request.type == OrderType.market ? 'MARKET' : 'LIMIT',
      'quantity': request.quantity.toString(),
      if (limitPrice != null) 'limitPrice': limitPrice.toString(),
    });
  }

  final Map<String, String> _fields;

  String toJsonString() => jsonEncode(_fields);
}
