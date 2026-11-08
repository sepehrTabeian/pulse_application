import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/services/order_cost_estimator.dart';

Decimal _d(String s) => Decimal.parse(s);

PriceQuote _quote({
  String? bid = '99',
  String? ask = '101',
  String last = '100',
}) => PriceQuote(
  symbol: 'A',
  last: _d(last),
  seq: 1,
  bid: bid == null ? null : _d(bid),
  ask: ask == null ? null : _d(ask),
);

CostEstimate? _est(
  OrderSide side,
  OrderType type,
  PriceQuote? quote, {
  String qty = '10',
  String? limit,
}) => const OrderCostEstimator().estimate(
  side: side,
  type: type,
  quantity: _d(qty),
  limitPrice: limit == null ? null : _d(limit),
  quote: quote,
);

void main() {
  test('market buy uses the ask', () {
    final e = _est(OrderSide.buy, OrderType.market, _quote())!;

    expect(e.amount, _d('1010'));
    expect(e.basis, CostBasis.ask);
  });

  test('market sell uses the bid', () {
    final e = _est(OrderSide.sell, OrderType.market, _quote())!;

    expect(e.amount, _d('990'));
    expect(e.basis, CostBasis.bid);
  });

  test('limit orders use the limit price regardless of the quote', () {
    final e = _est(OrderSide.buy, OrderType.limit, null, limit: '95.5')!;

    expect(e.amount, _d('955.0'));
    expect(e.basis, CostBasis.limit);
  });

  test('falls back to last (flagged) when bid/ask are missing', () {
    final e = _est(OrderSide.buy, OrderType.market, _quote(ask: null))!;

    expect(e.basis, CostBasis.last);
    expect(e.amount, _d('1000'));
  });

  test('is null when there is no price at all', () {
    expect(_est(OrderSide.buy, OrderType.market, null), isNull);
  });

  test('limit without a price yields no estimate', () {
    expect(_est(OrderSide.buy, OrderType.limit, _quote()), isNull);
  });

  test('fractional crypto quantities stay exact', () {
    final e = _est(
      OrderSide.buy,
      OrderType.market,
      _quote(ask: '67250.01'),
      qty: '0.0005',
    )!;

    expect(e.amount, _d('33.6250050'));
  });
}
