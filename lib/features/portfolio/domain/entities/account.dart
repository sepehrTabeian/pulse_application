import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class Position extends Equatable {
  const Position({
    required this.symbol,
    required this.quantity,
    this.averageCost,
  });

  final String symbol;
  final Decimal quantity;
  final Decimal? averageCost;

  @override
  List<Object?> get props => [symbol, quantity, averageCost];
}

/// Cash and positions as confirmed by the server (never computed locally).
class Account extends Equatable {
  const Account({
    required this.currency,
    required this.cash,
    required this.positions,
  });

  final String currency;
  final Decimal cash;
  final List<Position> positions;

  @override
  List<Object?> get props => [currency, cash, positions];
}
