import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/instruments/data/instrument_repository_impl.dart';
import 'package:pulse/features/portfolio/data/account_repository_impl.dart';
import 'package:pulse/features/watchlist/data/watchlist_repository_impl.dart';
import 'package:pulse_api/pulse_api.dart';

import '../support/fake_trading_remote_source.dart';
import '../support/recording_logger.dart';

RemoteCallGuard _guard() => RemoteCallGuard(
  mapper: const PulseApiExceptionMapper(),
  retryPolicy: RetryPolicy(
    baseDelay: const Duration(milliseconds: 1),
    maxDelay: const Duration(milliseconds: 2),
  ),
);

const _aapl =
    '{"symbol":"AAPL","name":"Apple","type":"STOCK","exchange":"NASDAQ",'
    '"currency":"USD","tickSize":"0.01","lotSize":"1","prevClose":"228",'
    '"tradable":true}';

Future<String> Function() _failOnce(String body) {
  var calls = 0;
  return () async {
    calls++;
    if (calls == 1) throw ApiException(503, 'SERVICE_UNAVAILABLE', 'm');
    return body;
  };
}

void main() {
  late FakeTradingRemoteSource source;
  late RecordingLogger logger;

  setUp(() {
    source = FakeTradingRemoteSource();
    logger = RecordingLogger();
  });

  group('InstrumentRepositoryImpl', () {
    InstrumentRepositoryImpl build() => InstrumentRepositoryImpl(
      source: source,
      guard: _guard(),
      logger: logger,
    );

    test('parses instruments and skips invalid ones with a warning', () async {
      source.onGetInstruments = () async =>
          '{"instruments":[$_aapl,{"symbol":null},{"symbol":"Z"},7]}';

      final list = await build().getInstruments();

      expect(list.map((i) => i.symbol), ['AAPL']);
      expect(logger.entries.where((e) => e.startsWith('warn')), isNotEmpty);
    });

    test('empty universe is an empty list', () async {
      source.onGetInstruments = () async => '{"instruments":[]}';

      expect(await build().getInstruments(), isEmpty);
    });

    test('missing/null/non-list envelope throws ParsingException', () async {
      for (final body in ['{}', '{"instruments":null}', '{"instruments":{}}']) {
        source.onGetInstruments = () async => body;

        await expectLater(
          build().getInstruments(),
          throwsA(isA<ParsingException>()),
          reason: body,
        );
      }
    });

    test('invalid JSON throws ParsingException', () async {
      source.onGetInstruments = () async => '<html>';

      await expectLater(
        build().getInstruments(),
        throwsA(isA<ParsingException>()),
      );
    });

    test('retries a transient 503', () async {
      source.onGetInstruments = _failOnce('{"instruments":[$_aapl]}');

      final list = await build().getInstruments();

      expect(list, hasLength(1));
      expect(source.count('getInstruments'), 2);
    });

    test('search trims the query and reads the results envelope', () async {
      source.onSearch = (_) async => '{"query":"app","results":[$_aapl]}';

      final list = await build().search('  app ');

      expect(list.single.symbol, 'AAPL');
      expect(source.lastArguments.single, 'app');
    });

    test('blank search returns [] without calling the server', () async {
      expect(await build().search('   '), isEmpty);
      expect(await build().search(''), isEmpty);
      expect(source.count('search'), 0);
    });

    test('search 400 keeps the server error mapped', () async {
      source.onSearch = (_) async =>
          throw ApiException(400, 'INVALID_REQUEST', 'm');

      await expectLater(
        build().search('x'),
        throwsA(isA<InvalidRequestException>()),
      );
    });
  });

  group('WatchlistRepositoryImpl', () {
    WatchlistRepositoryImpl build() =>
        WatchlistRepositoryImpl(source: source, guard: _guard());

    test('reads symbols in order', () async {
      source.onGetWatchlist = () async => '{"symbols":["B","A"]}';

      expect(await build().getSymbols(), ['B', 'A']);
    });

    test('unusable watchlist throws instead of returning empty', () async {
      source.onGetWatchlist = () async => '{"symbols":null}';

      await expectLater(build().getSymbols(), throwsA(isA<ParsingException>()));
    });

    test('replace sends the list and returns the saved server list', () async {
      source.onPutWatchlist = (symbols) async =>
          '{"symbols":${symbols.map((s) => '"$s"').toList()}}';

      final saved = await build().replaceSymbols(['A', 'B']);

      expect(saved, ['A', 'B']);
      expect(source.lastArguments.single, ['A', 'B']);
    });

    test('replace is idempotent so a transient 503 is retried', () async {
      var calls = 0;
      source.onPutWatchlist = (_) async {
        calls++;
        if (calls == 1) throw ApiException(503, 'SERVICE_UNAVAILABLE', 'm');
        return '{"symbols":["A"]}';
      };

      expect(await build().replaceSymbols(['A']), ['A']);
      expect(calls, 2);
    });

    test('WATCHLIST_FULL is a business rule and is not retried', () async {
      source.onPutWatchlist = (_) async =>
          throw ApiException(422, 'WATCHLIST_FULL', 'm');

      await expectLater(
        build().replaceSymbols(['A']),
        throwsA(isA<BusinessRuleException>()),
      );

      expect(source.count('putWatchlist'), 1);
    });
  });

  group('AccountRepositoryImpl', () {
    AccountRepositoryImpl build() =>
        AccountRepositoryImpl(source: source, guard: _guard(), logger: logger);

    test('parses cash and positions', () async {
      source.onGetAccount = () async =>
          '{"currency":"USD","cash":"100.5","positions":'
          '[{"symbol":"AAPL","quantity":"2","averageCost":"10"}]}';

      final account = await build().getAccount();

      expect(account.cash, Decimal.parse('100.5'));
      expect(account.positions.single.symbol, 'AAPL');
    });

    test('invalid positions are skipped with a warning', () async {
      source.onGetAccount = () async =>
          '{"cash":"1","positions":[{"symbol":"A","quantity":"x"}]}';

      final account = await build().getAccount();

      expect(account.positions, isEmpty);
      expect(logger.entries.where((e) => e.startsWith('warn')), isNotEmpty);
    });

    test('missing cash throws ParsingException', () async {
      source.onGetAccount = () async => '{"positions":[]}';

      await expectLater(build().getAccount(), throwsA(isA<ParsingException>()));
    });

    test('retries a transient 503', () async {
      source.onGetAccount = _failOnce('{"cash":"1"}');

      expect((await build().getAccount()).cash, Decimal.one);
    });
  });
}
