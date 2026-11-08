/// Raw access to the backend: every method returns the unparsed response.
/// This tiny seam (ISP at the data boundary) keeps repositories testable and
/// is the only thing that knows about the concrete backend.
abstract interface class TradingRemoteSource {
  Future<String> getInstruments();
  Future<String> searchInstruments(String query);
  Future<String> getWatchlist();
  Future<String> putWatchlist(List<String> symbols);
  Future<String> getAccount();
  Future<String> placeOrder(String requestJson);
  Future<String> getOrder(String clientOrderId);
  Future<String> getOrders();
  Future<String> getCandles(String symbol, String range);
  Stream<String> streamPrices(Set<String> symbols);
}
