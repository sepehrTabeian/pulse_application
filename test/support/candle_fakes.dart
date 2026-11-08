import 'package:decimal/decimal.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';

List<Candle> testCandles({int count = 10, double start = 100}) {
  return [
    for (var i = 0; i < count; i++)
      Candle(
        time: DateTime.utc(2026, 11, 2, 9).add(Duration(minutes: 5 * i)),
        open: Decimal.parse((start + i).toStringAsFixed(2)),
        high: Decimal.parse((start + i + 2).toStringAsFixed(2)),
        low: Decimal.parse((start + i - 1).toStringAsFixed(2)),
        close: Decimal.parse(
          (start + i + (i.isEven ? 1 : -0.5)).toStringAsFixed(2),
        ),
        volume: Decimal.fromInt(1000),
      ),
  ];
}

class FakeCandleReader implements CandleReader {
  final List<(String, CandleRange)> requests = [];
  Object? error;
  List<Candle> candles = testCandles();

  @override
  Future<List<Candle>> getCandles(String symbol, CandleRange range) async {
    requests.add((symbol, range));
    final e = error;
    if (e != null) throw e;
    return candles;
  }
}
