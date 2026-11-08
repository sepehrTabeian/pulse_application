import 'package:get_it/get_it.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/core/utils/id_generator.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';
import 'package:pulse/features/instruments/presentation/bloc/search_bloc.dart';
import 'package:pulse/features/orders/data/rejected_order_log_impl.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/trading/data/pending_order_store_impl.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';

/// Composition root for use cases, services and presentation (DI-01..03).
/// Requires the core and trading registrations first. Idempotent.
/// Blocs/Cubits are factories: every screen gets its own instance.
void configureAppDependencies(GetIt di, {required KeyValueStore store}) {
  if (di.isRegistered<PendingOrderStore>()) return;

  di
    ..registerLazySingleton<Clock>(SystemClock.new)
    ..registerLazySingleton<KeyValueStore>(() => store)
    ..registerLazySingleton<PendingOrderStore>(
      () => PendingOrderStoreImpl(di<KeyValueStore>()),
    )
    ..registerFactory<SubmitOrder>(
      () => SubmitOrder(
        placer: di<OrderPlacer>(),
        store: di<PendingOrderStore>(),
        backoff: di<RetryPolicy>(),
        clock: di<Clock>(),
      ),
    )
    ..registerFactory<ReconcilePendingOrders>(
      () => ReconcilePendingOrders(
        lookup: di<OrderLookup>(),
        store: di<PendingOrderStore>(),
      ),
    )
    ..registerFactory<LoadWatchlist>(
      () => LoadWatchlist(
        reader: di<WatchlistReader>(),
        catalog: di<InstrumentCatalog>(),
      ),
    )
    ..registerFactory<PriceFeedService>(
      () => PriceFeedService(
        source: di<PriceStreamSource>(),
        clock: di<Clock>(),
        backoff: di<RetryPolicy>(),
      ),
    )
    ..registerFactory<PriceFeedCubit>(
      () => PriceFeedCubit(di<PriceFeedService>()),
    )
    ..registerFactory<WatchlistCubit>(
      () => WatchlistCubit(
        loadWatchlist: di<LoadWatchlist>(),
        writer: di<WatchlistWriter>(),
        mapper: di<ExceptionMapper>(),
      ),
    )
    ..registerFactory<PortfolioCubit>(
      () => PortfolioCubit(
        reader: di<AccountReader>(),
        mapper: di<ExceptionMapper>(),
      ),
    )
    ..registerFactory<SearchBloc>(
      () => SearchBloc(
        searcher: di<InstrumentSearcher>(),
        mapper: di<ExceptionMapper>(),
      ),
    )
    ..registerFactoryParam<CandlesCubit, String, void>(
      (symbol, _) => CandlesCubit(
        symbol: symbol,
        reader: di<CandleReader>(),
        mapper: di<ExceptionMapper>(),
      ),
    )
    ..registerFactory<OrderRecoveryCubit>(
      () => OrderRecoveryCubit(di<ReconcilePendingOrders>()),
    )
    ..registerLazySingleton<RejectedOrderLog>(
      () => RejectedOrderLogImpl(di<KeyValueStore>()),
    )
    ..registerFactory<OrdersCubit>(
      () => OrdersCubit(
        reader: di<OrderHistoryReader>(),
        rejectedLog: di<RejectedOrderLog>(),
        catalog: di<InstrumentCatalog>(),
        mapper: di<ExceptionMapper>(),
      ),
    )
    ..registerFactory<OrderFlowBloc>(
      () => OrderFlowBloc(
        submitOrder: di<SubmitOrder>(),
        store: di<PendingOrderStore>(),
        idGenerator: di<IdGenerator>(),
        rejectedLog: di<RejectedOrderLog>(),
        clock: di<Clock>(),
      ),
    );
}
