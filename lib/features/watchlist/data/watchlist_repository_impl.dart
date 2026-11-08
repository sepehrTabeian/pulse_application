import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/features/watchlist/data/models/watchlist_model.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';

class WatchlistRepositoryImpl implements WatchlistReader, WatchlistWriter {
  WatchlistRepositoryImpl({
    required TradingRemoteSource source,
    required RemoteCallGuard guard,
  }) : _source = source,
       _guard = guard;

  final TradingRemoteSource _source;
  final RemoteCallGuard _guard;

  @override
  Future<List<String>> getSymbols() async {
    final body = await _guard.retrying(_source.getWatchlist);
    return _parse(body);
  }

  /// A full replace is idempotent, so transient failures are retried.
  @override
  Future<List<String>> replaceSymbols(List<String> symbols) async {
    final snapshot = List<String>.unmodifiable(symbols);
    final body = await _guard.retrying(() => _source.putWatchlist(snapshot));
    return _parse(body);
  }

  List<String> _parse(String body) {
    return WatchlistModel.fromJson(JsonReader.parse(body)).toSymbols();
  }
}
