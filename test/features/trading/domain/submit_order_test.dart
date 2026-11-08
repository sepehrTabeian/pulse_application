import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';

import '../../../support/fakes.dart';

SubmitOrder _useCase(ScriptedPlacer placer, InMemoryPendingOrderStore store) =>
    SubmitOrder(
      placer: placer,
      store: store,
      backoff: RetryPolicy(
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 1),
        random: Random(1),
      ),
      maxAttempts: 4,
    );

/// Runs [body] with the use case under fake time; returns the outcome.
SubmitOutcome _runOutcome(
  ScriptedPlacer placer,
  InMemoryPendingOrderStore store, {
  void Function(int attempt)? onResolving,
  bool resolveOnly = false,
}) {
  SubmitOutcome? outcome;
  Object? error;
  fakeAsync((async) {
    final useCase = _useCase(placer, store);
    final request = testRequest();
    final future = resolveOnly
        ? useCase.resolve(request, onResolving: onResolving)
        : useCase(request, onResolving: onResolving);
    future.then<void>(
      (v) {
        outcome = v;
      },
      onError: (Object e) {
        error = e;
      },
    );
    async.elapse(const Duration(minutes: 1));
  });
  if (error != null) throw error!;
  return outcome!;
}

void main() {
  late InMemoryPendingOrderStore store;

  setUp(() => store = InMemoryPendingOrderStore());

  test('persists the attempt BEFORE the first network call', () {
    final order = <String>[];
    store = InMemoryPendingOrderStore();
    final placer = ScriptedPlacer([
      (r) async {
        order.addAll(store.log);
        return testOrder(r);
      },
    ]);

    _runOutcome(placer, store);

    expect(order.first, startsWith('save:c1'));
  });

  test('a fill is confirmed and the record is removed', () {
    final placer = ScriptedPlacer([fills()]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderConfirmed>());
    expect((outcome as OrderConfirmed).order.status, OrderStatus.filled);
    expect(store.items, isEmpty);
    expect(placer.sent, hasLength(1));
  });

  test('a resting LIMIT order (working) is also a confirmed outcome', () {
    final placer = ScriptedPlacer([fills(OrderStatus.working)]);

    final outcome = _runOutcome(placer, store);

    expect((outcome as OrderConfirmed).order.status, OrderStatus.working);
  });

  test('timeouts are resolved by re-sending the SAME request and id', () {
    final placer = ScriptedPlacer([
      throwsAs(const RequestTimeoutException()),
      throwsAs(const RequestTimeoutException()),
      fills(),
    ]);
    final attempts = <int>[];

    final outcome = _runOutcome(placer, store, onResolving: attempts.add);

    expect(outcome, isA<OrderConfirmed>());
    expect(placer.sent, hasLength(3));
    expect(placer.sent.map((r) => r.clientOrderId).toSet(), {'c1'});
    expect(placer.sent.toSet(), hasLength(1), reason: 'identical payload');
    expect(attempts, [1, 2]);
    expect(store.items, isEmpty);
  });

  test('a 503 is retried with the same id', () {
    final placer = ScriptedPlacer([
      throwsAs(const ServiceUnavailableException()),
      fills(),
    ]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderConfirmed>());
    expect(placer.sent, hasLength(2));
  });

  test('an unknown status is not trusted: it keeps resolving', () {
    final placer = ScriptedPlacer([
      fills(OrderStatus.unknown),
      fills(OrderStatus.filled),
    ]);

    final outcome = _runOutcome(placer, store);

    expect((outcome as OrderConfirmed).order.status, OrderStatus.filled);
    expect(placer.sent, hasLength(2));
  });

  test('a definite rejection stops immediately and is not retried', () {
    final placer = ScriptedPlacer([
      throwsAs(const BusinessRuleException(code: 'INSUFFICIENT_FUNDS')),
    ]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderRejectedOutcome>());
    expect((outcome as OrderRejectedOutcome).error.code, 'INSUFFICIENT_FUNDS');
    expect(placer.sent, hasLength(1));
    expect(store.items, isEmpty);
  });

  test(
    'rejection after an ambiguous timeout is still reported as rejection',
    () {
      final placer = ScriptedPlacer([
        throwsAs(const RequestTimeoutException()),
        throwsAs(const BusinessRuleException(code: 'TRADING_HALTED')),
      ]);

      final outcome = _runOutcome(placer, store);

      expect(outcome, isA<OrderRejectedOutcome>());
    },
  );

  test('idempotency conflict is a rejection, never silently retried', () {
    final placer = ScriptedPlacer([
      throwsAs(const IdempotencyConflictException()),
    ]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderRejectedOutcome>());
    expect(placer.sent, hasLength(1));
  });

  test('exhausting attempts leaves the order UNRESOLVED and persisted', () {
    final placer = ScriptedPlacer([throwsAs(const RequestTimeoutException())]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderUnresolved>());
    expect(placer.sent, hasLength(4));
    expect(store.items['c1']!.unresolved, isTrue);
  });

  test('never reports a timeout as a failure or a fill', () {
    final placer = ScriptedPlacer([throwsAs(const RequestTimeoutException())]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isNot(isA<OrderRejectedOutcome>()));
    expect(outcome, isNot(isA<OrderConfirmed>()));
  });

  test('if the attempt cannot be persisted, NOTHING is sent', () {
    store.saveError = const StorageException();
    final placer = ScriptedPlacer([fills()]);

    expect(() => _runOutcome(placer, store), throwsA(isA<StorageException>()));
    expect(placer.sent, isEmpty);
  });

  test('a failing cleanup does not change a confirmed outcome', () {
    store.removeError = const StorageException();
    final placer = ScriptedPlacer([fills()]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderConfirmed>());
  });

  test('manual resolve re-sends the same request without re-persisting', () {
    final placer = ScriptedPlacer([fills()]);

    final outcome = _runOutcome(placer, store, resolveOnly: true);

    expect(outcome, isA<OrderConfirmed>());
    expect(store.log.where((l) => l.startsWith('save:c1:false')), isEmpty);
    expect(placer.sent.single.clientOrderId, 'c1');
  });

  test('other client errors are treated as unknown, not as failure', () {
    final placer = ScriptedPlacer([
      throwsAs(const UnexpectedException(cause: 'x')),
      fills(),
    ]);

    final outcome = _runOutcome(placer, store);

    expect(outcome, isA<OrderConfirmed>());
  });
}
