import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// One symbol's price at a point in time. `seq` increases per symbol.
class PriceQuote extends Equatable {
  const PriceQuote({
    required this.symbol,
    required this.last,
    required this.seq,
    this.bid,
    this.ask,
    this.timestamp,
  });

  final String symbol;
  final Decimal last;
  final int seq;

  /// Null when the server value was missing or unusable.
  final Decimal? bid;
  final Decimal? ask;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [symbol, last, seq, bid, ask, timestamp];
}

/// Messages we understand from the price stream. Anything else is dropped.
sealed class PriceMessage extends Equatable {
  const PriceMessage();
}

class PriceSnapshot extends PriceMessage {
  const PriceSnapshot(this.quotes);

  final List<PriceQuote> quotes;

  @override
  List<Object?> get props => [quotes];
}

class PriceTick extends PriceMessage {
  const PriceTick(this.quote);

  final PriceQuote quote;

  @override
  List<Object?> get props => [quote];
}

/// Proof that the connection is alive. [timestamp] may be unknown.
class PriceHeartbeat extends PriceMessage {
  const PriceHeartbeat([this.timestamp]);

  final DateTime? timestamp;

  @override
  List<Object?> get props => [timestamp];
}

/// Per-symbol error (e.g. UNKNOWN_SYMBOL); the stream stays open.
class PriceSymbolError extends PriceMessage {
  const PriceSymbolError({required this.code, this.symbol});

  final String code;
  final String? symbol;

  @override
  List<Object?> get props => [code, symbol];
}
