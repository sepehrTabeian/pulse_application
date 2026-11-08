import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';

/// Wire shape of the watchlist envelope.
class WatchlistModel {
  const WatchlistModel({this.symbols});

  factory WatchlistModel.fromJson(JsonReader json) {
    return WatchlistModel(symbols: json.strings('symbols'));
  }

  final List<String>? symbols;

  /// Ordered, trimmed, de-duplicated symbols. Throws when the list is
  /// missing: it must never be mistaken for an empty watchlist.
  List<String> toSymbols() {
    final raw = requireValue<List<String>>(symbols, 'symbols', 'list');
    final seen = <String>{};
    final result = <String>[];
    for (final item in raw) {
      final symbol = item.trim();
      if (symbol.isNotEmpty && seen.add(symbol)) result.add(symbol);
    }
    return List.unmodifiable(result);
  }
}
