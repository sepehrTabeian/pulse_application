import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Server-supported chart ranges (`1D` 5-min, `1W` hourly, `1M` daily bars).
enum CandleRange {
  day('1D'),
  week('1W'),
  month('1M');

  const CandleRange(this.wireValue);

  final String wireValue;
}

/// One OHLC bar. Invariant (checked when mapped from the wire):
/// `low <= open, close <= high` and every price is positive.
class Candle extends Equatable {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime time;
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final Decimal close;
  final Decimal volume;

  bool get isUp => close >= open;

  @override
  List<Object?> get props => [time, open, high, low, close, volume];
}
