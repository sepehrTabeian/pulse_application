import 'package:pulse/core/data/remote/trading_remote_source.dart';

/// Scriptable [TradingRemoteSource]. Every call is counted; unscripted calls
/// fail loudly so tests never pass by accident.
class FakeTradingRemoteSource implements TradingRemoteSource {
  Future<String> Function() onGetInstruments = _unscripted('getInstruments');
  Future<String> Function(String query) onSearch = _unscripted1('search');
  Future<String> Function() onGetWatchlist = _unscripted('getWatchlist');
  Future<String> Function(List<String> symbols) onPutWatchlist = _unscripted1(
    'putWatchlist',
  );
  Future<String> Function() onGetAccount = _unscripted('getAccount');
  Future<String> Function(String json) onPlaceOrder = _unscripted1(
    'placeOrder',
  );
  Future<String> Function(String id) onGetOrder = _unscripted1('getOrder');
  Future<String> Function() onGetOrders = _unscripted('getOrders');
  Future<String> Function(String symbol, String range) onGetCandles = (_, _) =>
      throw StateError('getCandles not scripted');
  Stream<String> Function(Set<String> symbols) onStream = (_) =>
      throw StateError('streamPrices not scripted');

  final Map<String, int> calls = {};
  final List<Object?> lastArguments = [];

  int count(String name) => calls[name] ?? 0;

  void _hit(String name, [Object? argument]) {
    calls[name] = count(name) + 1;
    lastArguments.add(argument);
  }

  @override
  Future<String> getInstruments() {
    _hit('getInstruments');
    return onGetInstruments();
  }

  @override
  Future<String> searchInstruments(String query) {
    _hit('search', query);
    return onSearch(query);
  }

  @override
  Future<String> getWatchlist() {
    _hit('getWatchlist');
    return onGetWatchlist();
  }

  @override
  Future<String> putWatchlist(List<String> symbols) {
    _hit('putWatchlist', symbols);
    return onPutWatchlist(symbols);
  }

  @override
  Future<String> getAccount() {
    _hit('getAccount');
    return onGetAccount();
  }

  @override
  Future<String> placeOrder(String requestJson) {
    _hit('placeOrder', requestJson);
    return onPlaceOrder(requestJson);
  }

  @override
  Future<String> getOrder(String clientOrderId) {
    _hit('getOrder', clientOrderId);
    return onGetOrder(clientOrderId);
  }

  @override
  Future<String> getOrders() {
    _hit('getOrders');
    return onGetOrders();
  }

  @override
  Future<String> getCandles(String symbol, String range) {
    _hit('getCandles', '$symbol|$range');
    return onGetCandles(symbol, range);
  }

  @override
  Stream<String> streamPrices(Set<String> symbols) {
    _hit('streamPrices', symbols);
    return onStream(symbols);
  }

  static Future<String> Function() _unscripted(String name) =>
      () => throw StateError('$name not scripted');

  static Future<String> Function(T) _unscripted1<T>(String name) =>
      (_) => throw StateError('$name not scripted');
}
