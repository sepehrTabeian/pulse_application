import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';

void main() {
  RetryPolicy policy({int maxAttempts = 4}) => RetryPolicy(
    maxAttempts: maxAttempts,
    baseDelay: const Duration(milliseconds: 100),
    maxDelay: const Duration(seconds: 2),
    random: Random(7),
  );

  group('run', () {
    test('returns the value without delay when the first call succeeds', () {
      fakeAsync((async) {
        String? result;
        policy().run(() async => 'ok').then((v) => result = v);

        async.flushMicrotasks();

        expect(result, 'ok');
      });
    });

    test('retries retryable failures until success', () {
      fakeAsync((async) {
        var calls = 0;
        String? result;
        policy()
            .run(() async {
              calls++;
              if (calls < 3) throw const ServiceUnavailableException();
              return 'ok';
            })
            .then((v) => result = v);

        async.elapse(const Duration(seconds: 30));

        expect(result, 'ok');
        expect(calls, 3);
      });
    });

    test('does not retry before the backoff delay has elapsed', () {
      fakeAsync((async) {
        var calls = 0;
        policy()
            .run(() async {
              calls++;
              throw const ServiceUnavailableException();
            })
            .then((_) {}, onError: (Object _) {});

        async.flushMicrotasks();

        expect(calls, 1);
      });
    });

    test('stops after maxAttempts and rethrows the last exception', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        policy(maxAttempts: 3)
            .run(() async {
              calls++;
              throw const ServiceUnavailableException();
            })
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );

        async.elapse(const Duration(minutes: 1));

        expect(calls, 3);
        expect(error, isA<ServiceUnavailableException>());
      });
    });

    test('non-retryable AppException is rethrown immediately', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        policy()
            .run(() async {
              calls++;
              throw const BusinessRuleException(code: 'INSUFFICIENT_FUNDS');
            })
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );

        async.elapse(const Duration(minutes: 1));

        expect(calls, 1);
        expect(error, isA<BusinessRuleException>());
      });
    });

    test('non-AppException errors propagate without retry', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        policy()
            .run(() async {
              calls++;
              throw StateError('bug');
            })
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );

        async.elapse(const Duration(minutes: 1));

        expect(calls, 1);
        expect(error, isA<StateError>());
      });
    });

    test('onRetry is called with attempt number and exception', () {
      fakeAsync((async) {
        final seen = <int>[];
        var calls = 0;
        policy().run(() async {
          calls++;
          if (calls < 3) throw const ServiceUnavailableException();
          return 1;
        }, onRetry: (attempt, error) => seen.add(attempt));

        async.elapse(const Duration(seconds: 30));

        expect(seen, [1, 2]);
      });
    });

    test('maxAttempts of 1 never retries', () {
      fakeAsync((async) {
        var calls = 0;
        policy(maxAttempts: 1)
            .run(() async {
              calls++;
              throw const ServiceUnavailableException();
            })
            .then((_) {}, onError: (Object _) {});

        async.elapse(const Duration(minutes: 1));

        expect(calls, 1);
      });
    });
  });

  group('delayFor', () {
    test('first delay is within base and base * 1.5', () {
      final d = policy().delayFor(1);

      expect(d, greaterThanOrEqualTo(const Duration(milliseconds: 100)));
      expect(d, lessThanOrEqualTo(const Duration(milliseconds: 150)));
    });

    test('grows with attempts until the cap', () {
      final p = policy();

      expect(p.delayFor(3), greaterThan(p.delayFor(1)));
    });

    test('never exceeds maxDelay even for huge attempt numbers', () {
      final p = policy();

      expect(p.delayFor(20), const Duration(seconds: 2));
      expect(p.delayFor(100000), const Duration(seconds: 2));
    });

    test('is deterministic for a seeded random', () {
      expect(
        RetryPolicy(random: Random(1)).delayFor(2),
        RetryPolicy(random: Random(1)).delayFor(2),
      );
    });
  });

  test('rejects maxAttempts below 1', () {
    expect(() => RetryPolicy(maxAttempts: 0), throwsA(isA<AssertionError>()));
  });
}
