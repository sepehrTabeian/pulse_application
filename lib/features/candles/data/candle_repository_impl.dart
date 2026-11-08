import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/features/candles/data/models/candle_model.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';

class CandleRepositoryImpl implements CandleReader {
  CandleRepositoryImpl({
    required TradingRemoteSource source,
    required RemoteCallGuard guard,
    required AppLogger logger,
  }) : _source = source,
       _guard = guard,
       _logger = logger;

  final TradingRemoteSource _source;
  final RemoteCallGuard _guard;
  final AppLogger _logger;

  @override
  Future<List<Candle>> getCandles(String symbol, CandleRange range) async {
    final cleanSymbol = symbol.trim();
    if (cleanSymbol.isEmpty) {
      throw const ValidationException(field: 'symbol', rule: 'required');
    }
    final body = await _guard.retrying(
      () => _source.getCandles(cleanSymbol, range.wireValue),
    );
    final items =
        JsonReader.parse(body).objects('candles') ??
        (throw const ParsingException(field: 'candles', expectedType: 'list'));
    final candles = mapLenient<CandleModel, Candle>(
      items.map(CandleModel.fromJson).toList(),
      (model) => model.toEntity(),
      onSkipped: (e) => _logger.warn('Skipped invalid candle: ${e.field}'),
    );
    return _oldestFirstUnique(candles);
  }

  /// Sorts by time and keeps the LAST bar for a repeated timestamp.
  static List<Candle> _oldestFirstUnique(List<Candle> candles) {
    final byTime = <DateTime, Candle>{for (final c in candles) c.time: c};
    final entries = byTime.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return List.unmodifiable([for (final e in entries) e.value]);
  }
}
