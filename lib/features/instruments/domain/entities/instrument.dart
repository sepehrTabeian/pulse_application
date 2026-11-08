import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum InstrumentType { stock, etf, crypto, other }

/// A tradable (or halted) instrument and its trading rules.
class Instrument extends Equatable {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.type,
    required this.exchange,
    required this.currency,
    required this.tickSize,
    required this.lotSize,
    required this.prevClose,
    required this.tradable,
    this.unit = '',
  });

  final String symbol;
  final String name;
  final InstrumentType type;
  final String exchange;
  final String currency;

  /// Limit prices must be a multiple of this (always > 0).
  final Decimal tickSize;

  /// Quantities must be a multiple of this (always > 0).
  final Decimal lotSize;

  /// Null when the server did not provide a usable value.
  final Decimal? prevClose;

  /// False = halted: no prices, orders rejected.
  final bool tradable;

  /// Trading unit: `share` for stocks/ETFs, the coin ticker for crypto.
  /// Empty when the server did not provide one.
  final String unit;

  @override
  List<Object?> get props => [
    symbol,
    name,
    type,
    exchange,
    currency,
    tickSize,
    lotSize,
    prevClose,
    tradable,
    unit,
  ];
}
