// Candles against the REAL simulator payloads (not hand-written JSON).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/di/trading_injection.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';
import 'package:pulse_api/pulse_api.dart';

void main() {
  late FakeTradingApi api;
  late GetIt di;

  setUp(() {
    api = FakeTradingApi(chaos: ChaosConfig.instant);
    di = GetIt.asNewInstance();
    configureCoreDependencies(di);
    configureTradingDependencies(di, api: api);
  });

  tearDown(() async {
    await di.reset();
    api.dispose();
  });

  test('each range returns the documented number of bars', () async {
    final reader = di<CandleReader>();

    expect((await reader.getCandles('AAPL', CandleRange.day)).length, 78);
    expect((await reader.getCandles('AAPL', CandleRange.week)).length, 35);
    expect((await reader.getCandles('AAPL', CandleRange.month)).length, 22);
  });

  test('bars are strictly ordered in time and internally consistent', () async {
    final bars = await di<CandleReader>().getCandles(
      'BTC-USD',
      CandleRange.day,
    );

    for (var i = 1; i < bars.length; i++) {
      expect(bars[i].time.isAfter(bars[i - 1].time), isTrue);
    }
    for (final b in bars) {
      expect(b.low <= b.open && b.open <= b.high, isTrue);
      expect(b.low <= b.close && b.close <= b.high, isTrue);
    }
  });

  test('every instrument in the universe yields a drawable chart', () async {
    final reader = di<CandleReader>();
    final instruments = await api.getInstruments();
    expect(instruments, isNotEmpty);

    for (final symbol in ['AAPL', 'MSFT', 'BTC-USD', 'ETH-USD']) {
      final bars = await reader.getCandles(symbol, CandleRange.week);
      expect(bars, isNotEmpty, reason: symbol);
    }
  });

  test('an unknown symbol is NotFoundException', () async {
    await expectLater(
      di<CandleReader>().getCandles('NOPE', CandleRange.day),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('a total outage ends as ServiceUnavailableException', () async {
    api.chaos = ChaosConfig.instant.copyWith(requestFailureRate: 1);

    await expectLater(
      di<CandleReader>().getCandles('AAPL', CandleRange.day),
      throwsA(isA<ServiceUnavailableException>()),
    );
  });
}
