/// Reads the user's ordered watchlist symbols.
///
/// Throws `ParsingException` when the server data is unusable. It never
/// returns an empty list in that case, because an empty list could later be
/// written back and wipe the user's real watchlist.
abstract interface class WatchlistReader {
  Future<List<String>> getSymbols();
}
