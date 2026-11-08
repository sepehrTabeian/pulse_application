import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';

import 'fakes.dart';

/// One scriptable backend implementing every read/write role the pages use.
class FakeBackend
    implements
        WatchlistReader,
        WatchlistWriter,
        InstrumentCatalog,
        InstrumentSearcher,
        AccountReader {
  FakeBackend({List<Instrument>? instruments, List<String>? watchlist})
    : instruments =
          instruments ??
          [
            testInstrument(symbol: 'AAPL'),
            testInstrument(symbol: 'HALT', tradable: false, prevClose: '40'),
            testInstrument(symbol: 'BTC', tick: '0.01', lot: '0.0001'),
          ],
      server = watchlist ?? ['AAPL', 'HALT'];

  final List<Instrument> instruments;
  List<String> server;
  Object? loadError;
  Object? putError;
  Object? accountError;
  int accountLoads = 0;
  final List<List<String>> puts = [];
  Account account = Account(
    currency: 'USD',
    cash: Decimal.parse('1000'),
    positions: const [],
  );

  @override
  Future<List<String>> getSymbols() async {
    final e = loadError;
    if (e != null) throw e;
    return server;
  }

  @override
  Future<List<Instrument>> getInstruments() async => instruments;

  @override
  Future<List<Instrument>> search(String query) async => [
    for (final i in instruments)
      if (i.symbol.toLowerCase().contains(query.toLowerCase())) i,
  ];

  @override
  Future<List<String>> replaceSymbols(List<String> symbols) async {
    puts.add(List.of(symbols));
    final e = putError;
    if (e != null) throw e;
    server = List.of(symbols);
    return server;
  }

  @override
  Future<Account> getAccount() async {
    accountLoads++;
    final e = accountError;
    if (e != null) throw e;
    return account;
  }
}

class FakeFeedSource implements PriceStreamSource {
  final List<StreamController<PriceMessage>> controllers = [];

  @override
  Stream<PriceMessage> watch(Set<String> symbols) {
    final c = StreamController<PriceMessage>();
    controllers.add(c);
    return c.stream;
  }

  void send(PriceMessage message) => controllers.last.add(message);

  void snapshot(Map<String, String> lastBySymbol, {String? bid, String? ask}) {
    send(
      PriceSnapshot([
        for (final e in lastBySymbol.entries)
          PriceQuote(
            symbol: e.key,
            last: Decimal.parse(e.value),
            seq: 1,
            bid: bid == null ? null : Decimal.parse(bid),
            ask: ask == null ? null : Decimal.parse(ask),
          ),
      ]),
    );
  }

  void tick(String symbol, String last, int seq, {String? bid, String? ask}) {
    send(
      PriceTick(
        PriceQuote(
          symbol: symbol,
          last: Decimal.parse(last),
          seq: seq,
          bid: bid == null ? null : Decimal.parse(bid),
          ask: ask == null ? null : Decimal.parse(ask),
        ),
      ),
    );
  }
}
