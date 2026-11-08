import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse_api/pulse_api.dart';

void main() {
  late GetIt di;

  setUp(() {
    di = GetIt.asNewInstance();
    configureCoreDependencies(di);
  });
  tearDown(() => di.reset());

  test('registers every role interface', () {
    configureTradingDependencies(di);

    expect(di<InstrumentCatalog>(), isNotNull);
    expect(di<InstrumentSearcher>(), isNotNull);
    expect(di<WatchlistReader>(), isNotNull);
    expect(di<WatchlistWriter>(), isNotNull);
    expect(di<PriceStreamSource>(), isNotNull);
    expect(di<OrderPlacer>(), isNotNull);
    expect(di<OrderLookup>(), isNotNull);
    expect(di<AccountReader>(), isNotNull);
  });

  test('role interfaces of one repository share the same instance', () {
    configureTradingDependencies(di);

    expect(di<WatchlistReader>(), same(di<WatchlistWriter>()));
    expect(di<OrderPlacer>(), same(di<OrderLookup>()));
    expect(di<InstrumentCatalog>(), same(di<InstrumentSearcher>()));
  });

  test('there is exactly ONE FakeTradingApi for the whole app', () {
    configureTradingDependencies(di);

    expect(di<FakeTradingApi>(), same(di<FakeTradingApi>()));
    expect(di<TradingRemoteSource>(), same(di<TradingRemoteSource>()));
  });

  test('configuring twice is safe', () {
    configureTradingDependencies(di);
    final first = di<FakeTradingApi>();

    configureTradingDependencies(di);

    expect(di<FakeTradingApi>(), same(first));
  });

  test('a provided api is used as the single instance', () {
    final api = FakeTradingApi(chaos: ChaosConfig.instant);
    addTearDown(api.dispose);

    configureTradingDependencies(di, api: api);

    expect(di<FakeTradingApi>(), same(api));
  });

  test('resetting the container disposes the lazily created api', () async {
    configureTradingDependencies(di);
    final api = di<FakeTradingApi>();

    await di.reset();

    expect(api.getInstruments, throwsA(anything));
  });
}
