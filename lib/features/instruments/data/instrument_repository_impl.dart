import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/features/instruments/data/models/instrument_model.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';

class InstrumentRepositoryImpl
    implements InstrumentCatalog, InstrumentSearcher {
  InstrumentRepositoryImpl({
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
  Future<List<Instrument>> getInstruments() async {
    final body = await _guard.retrying(_source.getInstruments);
    return _parse(body, 'instruments');
  }

  @override
  Future<List<Instrument>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const <Instrument>[];
    final body = await _guard.retrying(
      () => _source.searchInstruments(cleanQuery),
    );
    return _parse(body, 'results');
  }

  List<Instrument> _parse(String body, String key) {
    final items =
        JsonReader.parse(body).objects(key) ??
        (throw ParsingException(field: key, expectedType: 'list'));
    return mapLenient<InstrumentModel, Instrument>(
      items.map(InstrumentModel.fromJson).toList(),
      (model) => model.toEntity(),
      onSkipped: (e) => _logger.warn('Skipped invalid instrument: ${e.field}'),
    );
  }
}
