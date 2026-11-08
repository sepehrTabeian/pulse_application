import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';

/// Wire shape of one candle: `{"t","o","h","l","c","v"}`. Parsing never
/// throws; [toEntity] rejects bars that cannot be drawn truthfully.
class CandleModel {
  const CandleModel({
    this.time,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
  });

  factory CandleModel.fromJson(JsonReader json) {
    return CandleModel(
      time: json.dateTime('t'),
      open: json.decimal('o'),
      high: json.decimal('h'),
      low: json.decimal('l'),
      close: json.decimal('c'),
      volume: json.decimal('v'),
    );
  }

  final DateTime? time;
  final Decimal? open;
  final Decimal? high;
  final Decimal? low;
  final Decimal? close;
  final Decimal? volume;

  Candle toEntity() {
    final o = requireValue<Decimal>(open, 'o', 'decimal');
    final h = requireValue<Decimal>(high, 'h', 'decimal');
    final l = requireValue<Decimal>(low, 'l', 'decimal');
    final c = requireValue<Decimal>(close, 'c', 'decimal');
    final t = requireValue<DateTime>(time, 't', 'datetime');
    if (l <= Decimal.zero || h < l || o < l || o > h || c < l || c > h) {
      throw const ParsingException(
        field: 'ohlc',
        expectedType: 'positive prices with low <= open,close <= high',
      );
    }
    final v = volume;
    return Candle(
      time: t.toUtc(),
      open: o,
      high: h,
      low: l,
      close: c,
      volume: v != null && v >= Decimal.zero ? v : Decimal.zero,
    );
  }
}
