import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

class PositionValue extends Equatable {
  const PositionValue({
    required this.symbol,
    required this.quantity,
    required this.valueAtLast,
    required this.valueAtBid,
    required this.isApproximate,
    required this.hasPrice,
  });

  final String symbol;
  final Decimal quantity;
  final Decimal valueAtLast;
  final Decimal valueAtBid;

  /// True when a fallback price (previous close, or last instead of bid)
  /// was used.
  final bool isApproximate;

  /// False when no price at all was available (value counted as zero).
  final bool hasPrice;

  @override
  List<Object?> get props => [
    symbol,
    quantity,
    valueAtLast,
    valueAtBid,
    isApproximate,
    hasPrice,
  ];
}

/// Header numbers (ADR-0008): approximate value by `last`, and "sell-now"
/// value by `bid`. Pure and exact (Decimal).
class PortfolioValuation extends Equatable {
  const PortfolioValuation({
    required this.cash,
    required this.positions,
    required this.marketValueLast,
    required this.sellNowValue,
  });

  factory PortfolioValuation.compute({
    required Account account,
    required Map<String, PriceQuote> quotes,
    required Map<String, Instrument> instruments,
  }) {
    final positions = [
      for (final p in account.positions)
        _value(p, quotes[p.symbol], instruments[p.symbol]),
    ];
    return PortfolioValuation(
      cash: account.cash,
      positions: List.unmodifiable(positions),
      marketValueLast: positions.fold(
        Decimal.zero,
        (sum, p) => sum + p.valueAtLast,
      ),
      sellNowValue: positions.fold(
        Decimal.zero,
        (sum, p) => sum + p.valueAtBid,
      ),
    );
  }

  final Decimal cash;
  final List<PositionValue> positions;
  final Decimal marketValueLast;
  final Decimal sellNowValue;

  Decimal get totalAtLast => cash + marketValueLast;
  Decimal get totalSellNow => cash + sellNowValue;

  bool get hasApproximation => positions.any((p) => p.isApproximate);
  bool get hasMissingPrice => positions.any((p) => !p.hasPrice);

  static PositionValue _value(
    Position position,
    PriceQuote? quote,
    Instrument? instrument,
  ) {
    final quantity = position.quantity;
    if (quote != null) {
      final bid = quote.bid;
      return PositionValue(
        symbol: position.symbol,
        quantity: quantity,
        valueAtLast: quote.last * quantity,
        valueAtBid: (bid ?? quote.last) * quantity,
        isApproximate: bid == null,
        hasPrice: true,
      );
    }
    final prevClose = instrument?.prevClose;
    if (prevClose != null) {
      final value = prevClose * quantity;
      return PositionValue(
        symbol: position.symbol,
        quantity: quantity,
        valueAtLast: value,
        valueAtBid: value,
        isApproximate: true,
        hasPrice: true,
      );
    }
    return PositionValue(
      symbol: position.symbol,
      quantity: quantity,
      valueAtLast: Decimal.zero,
      valueAtBid: Decimal.zero,
      isApproximate: true,
      hasPrice: false,
    );
  }

  @override
  List<Object?> get props => [cash, positions, marketValueLast, sellNowValue];
}
