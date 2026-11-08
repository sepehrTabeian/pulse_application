import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/prices/data/price_stream_repository_impl.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse_api/pulse_api.dart';

import '../../../support/fake_trading_remote_source.dart';

String _tick(String symbol, int seq) =>
    '{"type":"tick","symbol":"$symbol","bid":"1","ask":"2","last":"1.5",'
    '"seq":$seq}';

void main() {
  late FakeTradingRemoteSource source;
  late PriceStreamRepositoryImpl repo;

  setUp(() {
    source = FakeTradingRemoteSource();
    repo = PriceStreamRepositoryImpl(
      source: source,
      guard: RemoteCallGuard(
        mapper: const PulseApiExceptionMapper(),
        retryPolicy: RetryPolicy(),
      ),
    );
  });

  test('maps raw messages to domain messages in order', () async {
    source.onStream = (_) => Stream.fromIterable([
      '{"type":"snapshot","prices":[{"symbol":"A","last":"1","seq":1}]}',
      _tick('A', 2),
      '{"type":"heartbeat"}',
    ]);

    final messages = await repo.watch({'A'}).toList();

    expect(messages[0], isA<PriceSnapshot>());
    expect(messages[1], isA<PriceTick>());
    expect(messages[2], isA<PriceHeartbeat>());
  });

  test('drops malformed and unknown messages without failing', () async {
    source.onStream = (_) => Stream.fromIterable([
      'garbage',
      '{"type":"tick","symbol":null,"last":"1","seq":1}',
      '{"type":"tick","symbol":"M","bid":"NaN","ask":"","last":"-","seq":"x"}',
      '{"type":"new_thing"}',
      _tick('A', 5),
    ]);

    final messages = await repo.watch({'A'}).toList();

    expect(messages, hasLength(1));
    expect((messages.single as PriceTick).quote.seq, 5);
  });

  test(
    'duplicates and out-of-order ticks are passed through untouched',
    () async {
      source.onStream = (_) =>
          Stream.fromIterable([_tick('A', 3), _tick('A', 3), _tick('A', 2)]);

      final seqs = (await repo.watch({
        'A',
      }).toList()).whereType<PriceTick>().map((m) => m.quote.seq).toList();

      expect(seqs, [3, 3, 2]);
    },
  );

  test('passes the requested symbols to the source', () async {
    source.onStream = (_) => const Stream<String>.empty();

    await repo.watch({'A', 'B'}).toList();

    expect(source.lastArguments.single, {'A', 'B'});
  });

  test(
    'empty symbol set yields an empty stream and opens no connection',
    () async {
      final messages = await repo.watch(<String>{}).toList();

      expect(messages, isEmpty);
      expect(source.count('streamPrices'), 0);
    },
  );

  test('blank symbols are ignored', () async {
    source.onStream = (_) => const Stream<String>.empty();

    await repo.watch({' ', 'A'}).toList();

    expect(source.lastArguments.single, {'A'});
  });

  test('a dropped connection becomes StreamDisconnectedException', () async {
    source.onStream = (_) async* {
      yield _tick('A', 1);
      throw ConnectionLostException();
    };
    final events = <Object>[];

    await repo
        .watch({'A'})
        .map<Object>((m) => m)
        .handleError(events.add)
        .forEach(events.add);

    expect(events.first, isA<PriceTick>());
    expect(events.last, isA<StreamDisconnectedException>());
  });

  test(
    'cancelling the subscription cancels the underlying connection',
    () async {
      var cancelled = false;
      final controller = StreamController<String>(
        onCancel: () => cancelled = true,
      );
      addTearDown(controller.close);
      source.onStream = (_) => controller.stream;

      final sub = repo.watch({'A'}).listen((_) {});
      controller.add(_tick('A', 1));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(cancelled, isTrue);
    },
  );
}
