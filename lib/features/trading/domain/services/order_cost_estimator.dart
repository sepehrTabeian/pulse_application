import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

/// Which price the estimate is based on (shown to the user, ADR-0007).
enum CostBasis { ask, bid, limit, last }

class CostEstimate extends Equatable {
  const CostEstimate({
    required this.amount,
    required this.price,
    required this.basis,
  });

  final Decimal amount;
  final Decimal price;
  final CostBasis basis;

  @override
  List<Object?> get props => [amount, price, basis];
}

/// MARKET BUY -> ask, MARKET SELL -> bid, LIMIT -> limit price (README).
/// An ESTIMATE only: the server decides the real fill.
class OrderCostEstimator {
  const OrderCostEstimator();

  CostEstimate? estimate({
    required OrderSide side,
    required OrderType type,
    required Decimal quantity,
    required Decimal? limitPrice,
    required PriceQuote? quote,
  }) {
    final priced = _price(side, type, limitPrice, quote);
    if (priced == null) return null;
    return CostEstimate(
      amount: priced.$1 * quantity,
      price: priced.$1,
      basis: priced.$2,
    );
  }

  (Decimal, CostBasis)? _price(
    OrderSide side,
    OrderType type,
    Decimal? limitPrice,
    PriceQuote? quote,
  ) {
    if (type == OrderType.limit) {
      return limitPrice == null ? null : (limitPrice, CostBasis.limit);
    }
    if (quote == null) return null;
    final sidePrice = side == OrderSide.buy ? quote.ask : quote.bid;
    if (sidePrice != null) {
      return (sidePrice, side == OrderSide.buy ? CostBasis.ask : CostBasis.bid);
    }
    return (quote.last, CostBasis.last);
  }
}
