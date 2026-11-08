import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';

Candle _bar(int hour) => Candle(
  time: DateTime.utc(2026, 1, 1, hour),
  open: Decimal.fromInt(10),
  high: Decimal.fromInt(12),
  low: Decimal.fromInt(9),
  close: Decimal.fromInt(11),
  volume: Decimal.zero,
);

class _Reader implements CandleReader {
  final List<CandleRange> requested = [];
  Future<List<Candle>> Function(CandleRange range) handler = (_) async => [
    _bar(1),
  ];

  @override
  Future<List<Candle>> getCandles(String symbol, CandleRange range) {
    requested.add(range);
    return handler(range);
  }
}

void main() {
  late _Reader reader;
  late CandlesCubit cubit;

  setUp(() {
    reader = _Reader();
    cubit = CandlesCubit(
      symbol: 'A',
      reader: reader,
      mapper: const PulseApiExceptionMapper(),
    );
  });
  tearDown(() => cubit.close());

  test('starts loading on the 1D range', () {
    expect(cubit.state.status, CandlesStatus.loading);
    expect(cubit.state.range, CandleRange.day);
  });

  test('load succeeds with bars', () async {
    await cubit.load();

    expect(cubit.state.status, CandlesStatus.ready);
    expect(cubit.state.candles, hasLength(1));
  });

  test('no bars is the empty state, not an error', () async {
    reader.handler = (_) async => const <Candle>[];

    await cubit.load();

    expect(cubit.state.status, CandlesStatus.empty);
  });

  test('failure carries a mapped exception and retry recovers', () async {
    reader.handler = (_) async => throw const ServiceUnavailableException();
    await cubit.load();
    expect(cubit.state.status, CandlesStatus.failure);
    expect(cubit.state.error, isA<ServiceUnavailableException>());

    reader.handler = (_) async => [_bar(1)];
    await cubit.load();

    expect(cubit.state.status, CandlesStatus.ready);
  });

  test('unknown errors are wrapped', () async {
    reader.handler = (_) async => throw StateError('x');

    await cubit.load();

    expect(cubit.state.error, isA<UnexpectedException>());
  });

  test(
    'setRange loads the new range; the same ready range is a no-op',
    () async {
      await cubit.load();

      await cubit.setRange(CandleRange.week);
      await cubit.setRange(CandleRange.week);

      expect(reader.requested, [CandleRange.day, CandleRange.week]);
      expect(cubit.state.range, CandleRange.week);
    },
  );

  test('a slow old response never overwrites a newer range', () async {
    final slow = Completer<List<Candle>>();
    reader.handler = (range) =>
        range == CandleRange.week ? slow.future : Future.value([_bar(2)]);

    final first = cubit.load(CandleRange.week);
    await cubit.load(CandleRange.month);
    slow.complete([_bar(9), _bar(10)]);
    await first;

    expect(cubit.state.range, CandleRange.month);
    expect(cubit.state.candles, hasLength(1));
  });

  test('retry on the same range after failure reloads', () async {
    reader.handler = (_) async => throw const ServiceUnavailableException();
    await cubit.load();
    reader.handler = (_) async => [_bar(1)];

    await cubit.setRange(CandleRange.day);

    expect(cubit.state.status, CandlesStatus.ready);
  });

  test('closing while loading is safe', () async {
    final gate = Completer<List<Candle>>();
    reader.handler = (_) => gate.future;
    final future = cubit.load();

    await cubit.close();
    gate.complete([_bar(1)]);

    await expectLater(future, completes);
  });

  group('live price', () {
    test('moves close and widens high/low of the newest bar only', () async {
      reader.handler = (_) async => [_bar(1), _bar(2)];
      await cubit.load();

      cubit.applyLivePrice(Decimal.fromInt(13));
      expect(cubit.state.candles.last.close, Decimal.fromInt(13));
      expect(cubit.state.candles.last.high, Decimal.fromInt(13));
      expect(cubit.state.candles.first.close, Decimal.fromInt(11));

      cubit.applyLivePrice(Decimal.fromInt(8));
      expect(cubit.state.candles.last.low, Decimal.fromInt(8));
      expect(cubit.state.candles.last.high, Decimal.fromInt(13));
    });

    test('is ignored after the cubit is closed (ticket popped)', () async {
      await cubit.load();
      await cubit.close();

      expect(() => cubit.applyLivePrice(Decimal.fromInt(13)), returnsNormally);
    });

    test('is ignored until candles are ready', () {
      cubit.applyLivePrice(Decimal.fromInt(13));

      expect(cubit.state.status, CandlesStatus.loading);
      expect(cubit.state.candles, isEmpty);
    });
  });
}
