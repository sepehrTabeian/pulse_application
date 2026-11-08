import 'package:equatable/equatable.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';

/// A watchlist entry joined with its trading rules.
class WatchlistItem extends Equatable {
  const WatchlistItem(this.instrument);

  final Instrument instrument;

  String get symbol => instrument.symbol;

  @override
  List<Object?> get props => [instrument];
}

class LoadedWatchlist extends Equatable {
  const LoadedWatchlist({required this.symbols, required this.instruments});

  /// Server order, including symbols we have no instrument data for.
  final List<String> symbols;
  final Map<String, Instrument> instruments;

  /// Items that can be displayed (instrument data known), in server order.
  List<WatchlistItem> get items => [
    for (final s in symbols)
      if (instruments[s] != null) WatchlistItem(instruments[s]!),
  ];

  @override
  List<Object?> get props => [symbols, instruments];
}

/// Loads the ordered symbols and the instrument catalogue in parallel.
class LoadWatchlist {
  const LoadWatchlist({
    required WatchlistReader reader,
    required InstrumentCatalog catalog,
  }) : _reader = reader,
       _catalog = catalog;

  final WatchlistReader _reader;
  final InstrumentCatalog _catalog;

  Future<LoadedWatchlist> call() async {
    final results = await Future.wait<Object>([
      _reader.getSymbols(),
      _catalog.getInstruments(),
    ]);
    final symbols = results[0] as List<String>;
    final instruments = results[1] as List<Instrument>;
    return LoadedWatchlist(
      symbols: symbols,
      instruments: Map.unmodifiable({for (final i in instruments) i.symbol: i}),
    );
  }
}
