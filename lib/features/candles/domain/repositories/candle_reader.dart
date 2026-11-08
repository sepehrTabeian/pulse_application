import 'package:pulse/features/candles/domain/entities/candle.dart';

/// Historical bars for one symbol, oldest first, without duplicates.
/// Throws `AppException` subtypes (`NotFoundException` for an unknown symbol).
abstract interface class CandleReader {
  Future<List<Candle>> getCandles(String symbol, CandleRange range);
}
