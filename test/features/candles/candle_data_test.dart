import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/candles/data/candle_repository_impl.dart';
import 'package:pulse/features/candles/data/models/candle_model.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse_api/pulse_api.dart';

import '../../support/fake_trading_remote_source.dart';
import '../../support/recording_logger.dart';

Decimal _d(String s) => Decimal.parse(s);

CandleModel _model(String json) => CandleModel.fromJson(JsonReader.parse(json));

String _bar(
  String t, {
  String o = '10',
  String h = '12',
  String l = '9',
  String c = '11',
  String v = '100',
}) => '{"t":"$t","o":"$o","h":"$h","l":"$l","c":"$c","v":$v}';

String _body(List<String> bars) =>
    '{"symbol":"A","range":"1D","candles":[${bars.join(',')}]}';

void main() {
  group('CandleModel', () {
    test('maps a valid bar with exact decimals', () {
      final c = _model(_bar('2026-11-02T13:00:00Z', c: '11.25')).toEntity();

      expect(c.time, DateTime.utc(2026, 11, 2, 13));
      expect(c.close, _d('11.25'));
      expect(c.volume, _d('100'));
      expect(c.isUp, isTrue);
    });

    test('a down bar is not up; flat counts as up', () {
      expect(
        _model(_bar('2026-01-01T00:00:00Z', o: '11', c: '10')).toEntity().isUp,
        isFalse,
      );
      expect(
        _model(_bar('2026-01-01T00:00:00Z', o: '10', c: '10')).toEntity().isUp,
        isTrue,
      );
    });

    test('parsing never throws on garbage', () {
      expect(
        () => _model('{"t":5,"o":[],"h":null,"l":{},"c":"x","v":true}'),
        returnsNormally,
      );
    });

    test('missing or unreadable required fields throw ParsingException', () {
      for (final json in [
        '{"o":"1","h":"2","l":"1","c":"1"}',
        '{"t":"2026-01-01T00:00:00Z","h":"2","l":"1","c":"1"}',
        '{"t":"bad","o":"1","h":"2","l":"1","c":"1"}',
        '{"t":"2026-01-01T00:00:00Z","o":"x","h":"2","l":"1","c":"1"}',
      ]) {
        expect(
          () => _model(json).toEntity(),
          throwsA(isA<ParsingException>()),
          reason: json,
        );
      }
    });

    test('impossible OHLC is rejected (cannot be drawn truthfully)', () {
      for (final bar in [
        _bar('2026-01-01T00:00:00Z', h: '8'),
        _bar('2026-01-01T00:00:00Z', l: '10.5', o: '10'),
        _bar('2026-01-01T00:00:00Z', c: '13'),
        _bar('2026-01-01T00:00:00Z', l: '0'),
        _bar('2026-01-01T00:00:00Z', l: '-1'),
      ]) {
        expect(
          () => _model(bar).toEntity(),
          throwsA(isA<ParsingException>()),
          reason: bar,
        );
      }
    });

    test('missing or negative volume becomes zero, not a failure', () {
      expect(
        _model(
          '{"t":"2026-01-01T00:00:00Z","o":"1","h":"2","l":"1","c":"1"}',
        ).toEntity().volume,
        Decimal.zero,
      );
      expect(
        _model(_bar('2026-01-01T00:00:00Z', v: '-5')).toEntity().volume,
        Decimal.zero,
      );
    });
  });

  group('CandleRepositoryImpl', () {
    late FakeTradingRemoteSource source;
    late RecordingLogger logger;
    late CandleRepositoryImpl repo;

    setUp(() {
      source = FakeTradingRemoteSource();
      logger = RecordingLogger();
      repo = CandleRepositoryImpl(
        source: source,
        guard: RemoteCallGuard(
          mapper: const PulseApiExceptionMapper(),
          retryPolicy: RetryPolicy(
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 2),
          ),
        ),
        logger: logger,
      );
    });

    test(
      'requests the wire range value and returns bars oldest first',
      () async {
        source.onGetCandles = (_, _) async => _body([
          _bar('2026-01-01T02:00:00Z'),
          _bar('2026-01-01T00:00:00Z'),
          _bar('2026-01-01T01:00:00Z'),
        ]);

        final bars = await repo.getCandles(' A ', CandleRange.week);

        expect(source.lastArguments.single, 'A|1W');
        expect(bars.map((c) => c.time.hour), [0, 1, 2]);
      },
    );

    test('duplicate timestamps keep the last bar', () async {
      source.onGetCandles = (_, _) async => _body([
        _bar('2026-01-01T00:00:00Z', c: '10'),
        _bar('2026-01-01T00:00:00Z', c: '11'),
      ]);

      final bars = await repo.getCandles('A', CandleRange.day);

      expect(bars, hasLength(1));
      expect(bars.single.close, _d('11'));
    });

    test('invalid bars are skipped and logged, others survive', () async {
      source.onGetCandles = (_, _) async => _body([
        _bar('2026-01-01T00:00:00Z'),
        _bar('2026-01-01T01:00:00Z', h: '1'),
        '5',
        _bar('2026-01-01T02:00:00Z'),
      ]);

      final bars = await repo.getCandles('A', CandleRange.day);

      expect(bars, hasLength(2));
      expect(logger.entries.where((e) => e.startsWith('warn')), isNotEmpty);
    });

    test('an empty list is an empty result, not an error', () async {
      source.onGetCandles = (_, _) async => _body([]);

      expect(await repo.getCandles('A', CandleRange.day), isEmpty);
    });

    test('a missing candles envelope throws ParsingException', () async {
      for (final body in ['{}', '{"candles":null}', '{"candles":{}}', 'oops']) {
        source.onGetCandles = (_, _) async => body;

        await expectLater(
          repo.getCandles('A', CandleRange.day),
          throwsA(isA<ParsingException>()),
          reason: body,
        );
      }
    });

    test('unknown symbol is NotFoundException', () async {
      source.onGetCandles = (_, _) async =>
          throw ApiException(404, 'UNKNOWN_SYMBOL', 'm');

      await expectLater(
        repo.getCandles('ZZZ', CandleRange.day),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('a transient 503 is retried', () async {
      var calls = 0;
      source.onGetCandles = (_, _) async {
        calls++;
        if (calls == 1) throw ApiException(503, 'SERVICE_UNAVAILABLE', 'm');
        return _body([_bar('2026-01-01T00:00:00Z')]);
      };

      expect(await repo.getCandles('A', CandleRange.day), hasLength(1));
      expect(calls, 2);
    });

    test('a blank symbol fails validation without a request', () async {
      await expectLater(
        repo.getCandles('  ', CandleRange.day),
        throwsA(isA<ValidationException>()),
      );

      expect(source.count('getCandles'), 0);
    });
  });
}
