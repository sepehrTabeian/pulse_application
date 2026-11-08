import 'package:get_it/get_it.dart';
import 'package:pulse/core/data/remote/fake_api_chaos_controller.dart';
import 'package:pulse/core/data/remote/fake_trading_api_remote_source.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/features/candles/data/candle_repository_impl.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';
import 'package:pulse/features/demo/domain/chaos_controller.dart';
import 'package:pulse/features/instruments/data/instrument_repository_impl.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/portfolio/data/account_repository_impl.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/prices/data/price_stream_repository_impl.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/trading/data/order_repository_impl.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/watchlist/data/watchlist_repository_impl.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse_api/pulse_api.dart';

/// Composition root for the trading data layer (DI-01..DI-03).
///
/// Requires [configureCoreDependencies] first. Idempotent. ONE
/// [FakeTradingApi] for the whole app (README); it is disposed with the
/// container.
void configureTradingDependencies(GetIt di, {FakeTradingApi? api}) {
  if (di.isRegistered<TradingRemoteSource>()) return;

  if (api != null) {
    di.registerSingleton<FakeTradingApi>(api);
  } else {
    di.registerLazySingleton<FakeTradingApi>(
      FakeTradingApi.new,
      dispose: (instance) => instance.dispose(),
    );
  }

  di
    ..registerLazySingleton<ChaosController>(
      () => FakeApiChaosController(di<FakeTradingApi>()),
    )
    ..registerLazySingleton<TradingRemoteSource>(
      () => FakeTradingApiRemoteSource(di<FakeTradingApi>()),
    )
    ..registerLazySingleton<RemoteCallGuard>(
      () => RemoteCallGuard(
        mapper: di<ExceptionMapper>(),
        retryPolicy: di<RetryPolicy>(),
      ),
    )
    ..registerLazySingleton<InstrumentRepositoryImpl>(
      () => InstrumentRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
        logger: di<AppLogger>(),
      ),
    )
    ..registerLazySingleton<InstrumentCatalog>(
      () => di<InstrumentRepositoryImpl>(),
    )
    ..registerLazySingleton<InstrumentSearcher>(
      () => di<InstrumentRepositoryImpl>(),
    )
    ..registerLazySingleton<WatchlistRepositoryImpl>(
      () => WatchlistRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
      ),
    )
    ..registerLazySingleton<WatchlistReader>(
      () => di<WatchlistRepositoryImpl>(),
    )
    ..registerLazySingleton<WatchlistWriter>(
      () => di<WatchlistRepositoryImpl>(),
    )
    ..registerLazySingleton<PriceStreamSource>(
      () => PriceStreamRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
      ),
    )
    ..registerLazySingleton<OrderRepositoryImpl>(
      () => OrderRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
      ),
    )
    ..registerLazySingleton<OrderPlacer>(() => di<OrderRepositoryImpl>())
    ..registerLazySingleton<OrderLookup>(() => di<OrderRepositoryImpl>())
    ..registerLazySingleton<OrderHistoryReader>(() => di<OrderRepositoryImpl>())
    ..registerLazySingleton<CandleReader>(
      () => CandleRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
        logger: di<AppLogger>(),
      ),
    )
    ..registerLazySingleton<AccountReader>(
      () => AccountRepositoryImpl(
        source: di<TradingRemoteSource>(),
        guard: di<RemoteCallGuard>(),
        logger: di<AppLogger>(),
      ),
    );
}
