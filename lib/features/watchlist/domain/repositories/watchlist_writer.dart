/// Replaces the whole watchlist on the server and returns the saved list
/// (the server's truth). Idempotent. Throws `AppException` subtypes.
abstract interface class WatchlistWriter {
  Future<List<String>> replaceSymbols(List<String> symbols);
}
