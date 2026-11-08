import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse_api/pulse_api.dart';

/// Adapter over the ONE shared [FakeTradingApi] instance (README rule).
class FakeTradingApiRemoteSource implements TradingRemoteSource {
  const FakeTradingApiRemoteSource(this._api);

  final FakeTradingApi _api;

  @override
  Future<String> getInstruments() => _api.getInstruments();

  @override
  Future<String> searchInstruments(String query) =>
      _api.searchInstruments(query);

  @override
  Future<String> getWatchlist() => _api.getWatchlist();

  @override
  Future<String> putWatchlist(List<String> symbols) =>
      _api.putWatchlist(symbols);

  @override
  Future<String> getAccount() => _api.getAccount();

  @override
  Future<String> placeOrder(String requestJson) => _api.placeOrder(requestJson);

  @override
  Future<String> getOrder(String clientOrderId) => _api.getOrder(clientOrderId);

  @override
  Future<String> getOrders() => _api.getOrders();

  @override
  Future<String> getCandles(String symbol, String range) =>
      _api.getCandles(symbol, range: range);

  @override
  Stream<String> streamPrices(Set<String> symbols) =>
      _api.streamPrices(symbols);
}
