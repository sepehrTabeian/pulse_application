import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';

class _Source implements PriceStreamSource {
  final List<Set<String>> requested = [];
  final List<StreamController<PriceMessage>> controllers = [];

  @override
  Stream<PriceMessage> watch(Set<String> symbols) {
    requested.add(symbols);
    final c = StreamController<PriceMessage>();
    controllers.add(c);
    return c.stream;
  }
}

void _run(
  void Function(PriceFeedCubit cubit, _Source source, FakeAsync a) body,
) {
  fakeAsync((async) {
    final source = _Source();
    final cubit = PriceFeedCubit(
      PriceFeedService(source: source, clock: const SystemClock()),
    );
    body(cubit, source, async);
    cubit.close();
    async.flushMicrotasks();
  });
}

void main() {
  test('connects to the union of watchlist and position symbols', () {
    _run((cubit, source, async) {
      cubit.setWatchlistSymbols(['A', 'B']);
      cubit.setPositionSymbols(['B', 'C']);

      expect(source.requested.last, {'A', 'B', 'C'});
    });
  });

  test('a position outside the watchlist keeps being subscribed', () {
    _run((cubit, source, async) {
      cubit.setPositionSymbols(['P']);
      cubit.setWatchlistSymbols(['A']);
      cubit.setWatchlistSymbols([]);

      expect(source.requested.first, {'P'});
      expect(source.requested.every((s) => s.contains('P')), isTrue);
    });
  });

  test('nothing to subscribe means no connection', () {
    _run((cubit, source, async) {
      cubit.setWatchlistSymbols([]);
      cubit.setPositionSymbols([]);

      expect(source.requested, isEmpty);
    });
  });

  test('publishes service state to listeners', () {
    _run((cubit, source, async) {
      cubit.setWatchlistSymbols(['A']);
      source.controllers.last.add(
        PriceSnapshot([
          PriceQuote(symbol: 'A', last: Decimal.parse('5'), seq: 1),
        ]),
      );
      async.elapse(const Duration(milliseconds: 300));

      expect(cubit.state.status, FeedStatus.live);
      expect(cubit.state.quotes['A']!.last, Decimal.parse('5'));
    });
  });

  test('pause and resume are forwarded', () {
    _run((cubit, source, async) {
      cubit.setWatchlistSymbols(['A']);
      cubit.pause();
      cubit.resume();

      expect(source.requested, hasLength(2));
    });
  });

  test('closing disposes the service (no leaked connection or timers)', () {
    fakeAsync((async) {
      final source = _Source();
      final cubit = PriceFeedCubit(
        PriceFeedService(source: source, clock: const SystemClock()),
      );
      cubit.setWatchlistSymbols(['A']);

      cubit.close();
      async.elapse(Duration.zero);

      expect(async.pendingTimers, isEmpty);
    });
  });
}
