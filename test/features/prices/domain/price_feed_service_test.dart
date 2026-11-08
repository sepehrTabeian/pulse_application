import 'dart:async';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';

class _Conn {
  _Conn(this.symbols);
  final Set<String> symbols;
  final StreamController<PriceMessage> controller =
      StreamController<PriceMessage>();
  bool cancelled = false;

  void send(PriceMessage m) => controller.add(m);
  void fail() => controller.addError(const StreamDisconnectedException());
}

class _FakeSource implements PriceStreamSource {
  final List<_Conn> conns = [];

  @override
  Stream<PriceMessage> watch(Set<String> symbols) {
    final c = _Conn(symbols);
    c.controller.onCancel = () => c.cancelled = true;
    conns.add(c);
    return c.controller.stream;
  }

  int get open => conns.where((c) => !c.cancelled).length;
  _Conn get last => conns.last;
}

PriceQuote _q(String s, int seq, [String last = '1']) =>
    PriceQuote(symbol: s, last: Decimal.parse(last), seq: seq);

PriceSnapshot _snap(List<String> symbols) =>
    PriceSnapshot([for (final s in symbols) _q(s, 1)]);

void main() {
  late _FakeSource source;
  late PriceFeedService service;

  void setUpService() {
    source = _FakeSource();
    service = PriceFeedService(
      source: source,
      clock: const SystemClock(),
      backoff: RetryPolicy(
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 8),
        random: Random(1),
      ),
    );
  }

  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      setUpService();
      body(async);
      service.dispose();
      async.flushMicrotasks();
    });
  }

  test('does not open a connection without symbols', () {
    run((async) {
      service.setSymbols({});

      expect(source.conns, isEmpty);
      expect(service.current.status, FeedStatus.connecting);
    });
  });

  test('opens one connection for the requested symbols', () {
    run((async) {
      service.setSymbols({'A', 'B'});

      expect(source.conns, hasLength(1));
      expect(source.last.symbols, {'A', 'B'});
    });
  });

  test('re-setting the same symbols does not reconnect', () {
    run((async) {
      service.setSymbols({'A'});
      service.setSymbols({'A'});

      expect(source.conns, hasLength(1));
    });
  });

  test('snapshot makes the feed live with quotes', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      expect(service.current.status, FeedStatus.live);
      expect(service.current.quotes.keys, ['A']);
    });
  });

  test('a burst of ticks is coalesced into few emissions with the latest', () {
    run((async) {
      final emitted = <PriceFeedState>[];
      service.states.listen(emitted.add);
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));
      emitted.clear();

      for (var i = 2; i <= 101; i++) {
        source.last.send(PriceTick(_q('A', i, '$i')));
      }
      async.elapse(const Duration(milliseconds: 20));
      expect(emitted, isEmpty, reason: 'not published before the interval');
      async.elapse(const Duration(milliseconds: 300));

      expect(emitted.length, lessThanOrEqualTo(2));
      expect(service.current.quotes['A']!.seq, 101);
    });
  });

  test('duplicate and out-of-order ticks do not change the book', () {
    run((async) {
      service.setSymbols({'A'});
      source.last
        ..send(_snap(['A']))
        ..send(PriceTick(_q('A', 10, '10')))
        ..send(PriceTick(_q('A', 10, '99')))
        ..send(PriceTick(_q('A', 9, '99')));
      async.elapse(const Duration(seconds: 1));

      expect(service.current.quotes['A']!.last, Decimal.parse('10'));
    });
  });

  test('heartbeats alone keep the feed live (halted/quiet symbols)', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      for (var i = 0; i < 12; i++) {
        async.elapse(const Duration(seconds: 2));
        source.last.send(const PriceHeartbeat());
      }
      async.elapse(const Duration(milliseconds: 500));

      expect(service.current.status, FeedStatus.live);
    });
  });

  test('silence turns live into stale after 6 s and offline after 15 s', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(seconds: 1));
      expect(service.current.status, FeedStatus.live);

      async.elapse(const Duration(seconds: 6));
      expect(service.current.status, FeedStatus.stale);

      async.elapse(const Duration(seconds: 10));
      expect(service.current.status, FeedStatus.offline);
    });
  });

  test('never receiving anything becomes offline, not stuck connecting', () {
    run((async) {
      service.setSymbols({'A'});

      async.elapse(const Duration(seconds: 16));

      expect(service.current.status, FeedStatus.offline);
    });
  });

  test('a stream error reconnects with backoff and recovers', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      source.last.fail();
      async.flushMicrotasks();
      expect(service.current.isReconnecting, isTrue);
      expect(source.conns, hasLength(1));

      async.elapse(const Duration(milliseconds: 2000));
      expect(source.conns, hasLength(2));
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      expect(service.current.status, FeedStatus.live);
      expect(service.current.isReconnecting, isFalse);
    });
  });

  test('a stream that simply closes is also reconnected', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.flushMicrotasks();

      source.last.controller.close();
      async.elapse(const Duration(seconds: 3));

      expect(source.conns, hasLength(2));
    });
  });

  test('repeated failures back off with growing delays and never storm', () {
    run((async) {
      service.setSymbols({'A'});
      for (var i = 0; i < 4; i++) {
        source.last.fail();
        async.elapse(const Duration(seconds: 20));
      }

      // Without growth the 80 s window would allow ~80 reconnects.
      expect(source.conns.length, lessThanOrEqualTo(6));
      expect(source.conns.length, greaterThan(1));
    });
  });

  test('changing symbols swaps connections without a gap', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));
      final first = source.last;

      service.setSymbols({'B'});
      expect(source.conns, hasLength(2));
      expect(first.cancelled, isFalse, reason: 'old stream kept until swap');
      expect(service.current.quotes.keys, ['A']);

      source.conns[1].send(_snap(['B']));
      async.elapse(const Duration(milliseconds: 200));

      expect(first.cancelled, isTrue);
      expect(service.current.quotes.keys, ['B']);
      expect(service.current.status, FeedStatus.live);
      expect(source.open, 1);
    });
  });

  test('a failing candidate keeps the old stream and retries later', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));
      final first = source.last;

      service.setSymbols({'A', 'B'});
      source.conns[1].fail();
      async.flushMicrotasks();
      expect(first.cancelled, isFalse);

      async.elapse(const Duration(seconds: 3));
      expect(source.conns.length, 3, reason: 'candidate retried');
      source.conns[2].send(_snap(['A', 'B']));
      async.elapse(const Duration(milliseconds: 200));

      expect(first.cancelled, isTrue);
      expect(service.current.quotes.keys, containsAll(['A', 'B']));
    });
  });

  test('symbols changed twice quickly only keeps the latest candidate', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      service.setSymbols({'B'});
      final candidateB = source.last;
      service.setSymbols({'C'});

      expect(candidateB.cancelled, isTrue);
      expect(source.last.symbols, {'C'});
    });
  });

  test('clearing symbols closes everything and empties the book', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      service.setSymbols({});
      async.elapse(const Duration(milliseconds: 200));

      expect(source.open, 0);
      expect(service.current.quotes, isEmpty);
    });
  });

  test('pause closes the connection; resume reconnects', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      service.pause();
      expect(source.open, 0);
      async.elapse(const Duration(seconds: 60));
      expect(source.conns, hasLength(1), reason: 'no reconnect while paused');

      service.resume();
      expect(source.conns, hasLength(2));
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));
      expect(service.current.status, FeedStatus.live);
    });
  });

  test('pause during a pending reconnect cancels it', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.fail();
      async.flushMicrotasks();

      service.pause();
      async.elapse(const Duration(seconds: 30));

      expect(source.conns, hasLength(1));
    });
  });

  test('dispose releases connections and leaves no timers', () {
    fakeAsync((async) {
      setUpService();
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));

      service.dispose();
      async.flushMicrotasks();

      expect(source.open, 0);
      expect(async.pendingTimers, isEmpty);
      service.setSymbols({'B'});
      expect(source.conns, hasLength(1), reason: 'ignored after dispose');
    });
  });

  test('messages from a cancelled connection are ignored', () {
    run((async) {
      service.setSymbols({'A'});
      source.last.send(_snap(['A']));
      async.elapse(const Duration(milliseconds: 200));
      final old = source.last;
      service.setSymbols({'B'});
      source.conns[1].send(_snap(['B']));
      async.elapse(const Duration(milliseconds: 200));

      old.send(PriceTick(_q('A', 50)));
      async.elapse(const Duration(seconds: 1));

      expect(service.current.quotes.keys, ['B']);
    });
  });
}
