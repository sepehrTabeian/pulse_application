// Contract tests: our models/repositories against the REAL pulse_api payloads
// (not hand-written JSON), including its misbehaviour modes.
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/fake_trading_api_remote_source.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/instruments/data/instrument_repository_impl.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/repositories/order_lookup.dart';
import 'package:pulse/features/trading/domain/repositories/order_placer.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_reader.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse_api/pulse_api.dart';

import '../support/recording_logger.dart';

OrderRequest _buy(Instrument i, String id, {Decimal? quantity}) => OrderRequest(
  clientOrderId: id,
  symbol: i.symbol,
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: quantity ?? i.lotSize,
);

Decimal _qty(Account a, String symbol) => a.positions
    .where((p) => p.symbol == symbol)
    .fold(Decimal.zero, (sum, p) => sum + p.quantity);

void main() {
  late FakeTradingApi api;
  late GetIt di;
  late List<Instrument> instruments;
  late Instrument tradable;

  setUp(() async {
    api = FakeTradingApi(
      chaos: ChaosConfig.instant,
      requestTimeout: const Duration(milliseconds: 20),
    );
    di = GetIt.asNewInstance();
    configureCoreDependencies(di);
    configureTradingDependencies(di, api: api);
    instruments = await di<InstrumentCatalog>().getInstruments();
    tradable = instruments.firstWhere((i) => i.tradable);
  });

  tearDown(() async {
    await di.reset();
    api.dispose();
  });

  group('instruments', () {
    test('every real instrument parses (nothing is skipped)', () async {
      final logger = RecordingLogger();
      final repo = InstrumentRepositoryImpl(
        source: FakeTradingApiRemoteSource(api),
        guard: di<RemoteCallGuard>(),
        logger: logger,
      );

      final list = await repo.getInstruments();

      expect(list, isNotEmpty);
      expect(logger.entries, isEmpty);
      expect(list.every((i) => i.tickSize > Decimal.zero), isTrue);
    });

    test('the universe includes a halted instrument', () {
      expect(instruments.where((i) => !i.tradable), isNotEmpty);
    });

    test('fractional lot sizes are preserved exactly (crypto)', () {
      final crypto = instruments.firstWhere(
        (i) => i.type == InstrumentType.crypto,
      );

      expect(crypto.lotSize.scale, greaterThan(0));
    });
  });

  group('watchlist', () {
    test('reads the seeded list and round-trips a replacement', () async {
      final reader = di<WatchlistReader>();
      final writer = di<WatchlistWriter>();
      expect(await reader.getSymbols(), isNotEmpty);
      final wanted = [instruments[1].symbol, instruments[0].symbol];

      final saved = await writer.replaceSymbols(wanted);

      expect(saved, wanted);
      expect(await reader.getSymbols(), wanted);
    });

    test('duplicates are rejected by the server as InvalidRequest', () async {
      final s = instruments.first.symbol;

      await expectLater(
        di<WatchlistWriter>().replaceSymbols([s, s]),
        throwsA(isA<InvalidRequestException>()),
      );
    });

    test('more than 20 symbols is a WATCHLIST_FULL business rule', () async {
      if (instruments.length < 21) {
        markTestSkipped('fewer than 21 instruments in the simulator');
        return;
      }

      await expectLater(
        di<WatchlistWriter>().replaceSymbols(
          instruments.take(21).map((i) => i.symbol).toList(),
        ),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.code,
            'code',
            'WATCHLIST_FULL',
          ),
        ),
      );
    });
  });

  group('orders', () {
    test('market buy fills and is visible in account and lookup', () async {
      final before = await di<AccountReader>().getAccount();

      final order = await di<OrderPlacer>().place(_buy(tradable, 'c-fill'));

      expect(order.status, OrderStatus.filled);
      expect(order.averagePrice, isNotNull);
      final after = await di<AccountReader>().getAccount();
      expect(after.cash < before.cash, isTrue);
      expect(
        _qty(after, tradable.symbol) - _qty(before, tradable.symbol),
        tradable.lotSize,
      );
      final looked = await di<OrderLookup>().getByClientOrderId('c-fill');
      expect(looked.orderId, order.orderId);
    });

    test(
      're-sending the same id and params returns the original order',
      () async {
        final first = await di<OrderPlacer>().place(_buy(tradable, 'c-same'));
        final before = await di<AccountReader>().getAccount();

        final second = await di<OrderPlacer>().place(_buy(tradable, 'c-same'));

        expect(second.orderId, first.orderId);
        final after = await di<AccountReader>().getAccount();
        expect(after.cash, before.cash);
      },
    );

    test('same id with different params is an idempotency conflict', () async {
      await di<OrderPlacer>().place(_buy(tradable, 'c-conflict'));

      await expectLater(
        di<OrderPlacer>().place(
          _buy(
            tradable,
            'c-conflict',
            quantity: tradable.lotSize * Decimal.fromInt(2),
          ),
        ),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });

    test('quantity off the lot grid is rejected as INVALID_QUANTITY', () async {
      final bad =
          tradable.lotSize +
          (tradable.lotSize / Decimal.fromInt(2)).toDecimal();

      await expectLater(
        di<OrderPlacer>().place(_buy(tradable, 'c-bad', quantity: bad)),
        throwsA(
          isA<InvalidRequestException>().having(
            (e) => e.code,
            'code',
            'INVALID_QUANTITY',
          ),
        ),
      );
    });

    test('halted instrument is rejected as TRADING_HALTED', () async {
      final halted = instruments.firstWhere((i) => !i.tradable);

      await expectLater(
        di<OrderPlacer>().place(_buy(halted, 'c-halt')),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.code,
            'code',
            'TRADING_HALTED',
          ),
        ),
      );
    });

    test('unknown order lookup is NotFoundException', () async {
      await expectLater(
        di<OrderLookup>().getByClientOrderId('does-not-exist'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'GHOST TIMEOUT: unknown outcome, then same id resolves it once only',
      () async {
        final before = await di<AccountReader>().getAccount();
        api.chaos = ChaosConfig.instant.copyWith(ghostTimeoutRate: 1);

        await expectLater(
          di<OrderPlacer>().place(_buy(tradable, 'c-ghost')),
          throwsA(isA<RequestTimeoutException>()),
        );
        api.chaos = ChaosConfig.instant;
        final resolved = await di<OrderPlacer>().place(
          _buy(tradable, 'c-ghost'),
        );

        expect(resolved.status, OrderStatus.filled);
        final after = await di<AccountReader>().getAccount();
        expect(
          _qty(after, tradable.symbol) - _qty(before, tradable.symbol),
          tradable.lotSize,
          reason: 'the order must have executed exactly once',
        );
        expect(
          (await di<OrderLookup>().getByClientOrderId('c-ghost')).orderId,
          resolved.orderId,
        );
      },
    );
  });

  group('resilience', () {
    test('a total 503 outage ends as ServiceUnavailableException', () async {
      api.chaos = ChaosConfig.instant.copyWith(requestFailureRate: 1);
      final guard = RemoteCallGuard(
        mapper: const PulseApiExceptionMapper(),
        retryPolicy: RetryPolicy(
          maxAttempts: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 2),
          random: Random(1),
        ),
      );
      final repo = InstrumentRepositoryImpl(
        source: FakeTradingApiRemoteSource(api),
        guard: guard,
        logger: RecordingLogger(),
      );

      await expectLater(
        repo.getInstruments(),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });
  });

  group('price stream', () {
    test(
      'starts with a snapshot of the requested symbols, then ticks',
      () async {
        final symbols = {tradable.symbol};

        final messages = await di<PriceStreamSource>()
            .watch(symbols)
            .take(4)
            .toList();

        expect(messages.first, isA<PriceSnapshot>());
        final snapshot = messages.first as PriceSnapshot;
        expect(snapshot.quotes.map((q) => q.symbol), contains(tradable.symbol));
        expect(messages.whereType<PriceTick>(), isNotEmpty);
      },
    );

    test('survives malformed, duplicate and out-of-order messages', () async {
      api.chaos = ChaosConfig.instant.copyWith(
        malformedMessageRate: 0.3,
        outOfOrderTickRate: 0.2,
        duplicateTickRate: 0.2,
      );

      final messages = await di<PriceStreamSource>()
          .watch({tradable.symbol})
          .take(60)
          .toList();

      expect(messages, hasLength(60));
      expect(
        messages.every(
          (m) =>
              m is PriceSnapshot ||
              m is PriceTick ||
              m is PriceHeartbeat ||
              m is PriceSymbolError,
        ),
        isTrue,
      );
      final seqs = messages
          .whereType<PriceTick>()
          .map((m) => m.quote.seq)
          .toList();
      expect(seqs.length, greaterThan(10));
    });

    test(
      'a forced disconnect surfaces as StreamDisconnectedException',
      () async {
        api.chaos = ChaosConfig.instant.copyWith(
          meanTimeBetweenDisconnects: const Duration(milliseconds: 30),
        );
        final errors = <Object>[];

        await di<PriceStreamSource>()
            .watch({tradable.symbol})
            .handleError(errors.add)
            .drain<void>();

        expect(errors.whereType<StreamDisconnectedException>(), isNotEmpty);
      },
    );

    test(
      'closing the subscription releases the connection (no leak)',
      () async {
        final sub = di<PriceStreamSource>()
            .watch({tradable.symbol})
            .listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(api.openConnectionCount, 1);

        await sub.cancel();

        expect(api.openConnectionCount, 0);
      },
    );
  });
}
