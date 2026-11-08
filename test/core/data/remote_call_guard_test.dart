import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse_api/pulse_api.dart';

RemoteCallGuard _guard() => RemoteCallGuard(
  mapper: const PulseApiExceptionMapper(),
  retryPolicy: RetryPolicy(
    maxAttempts: 3,
    baseDelay: const Duration(milliseconds: 10),
    maxDelay: const Duration(milliseconds: 20),
    random: Random(1),
  ),
);

ApiException _api(int status, [String code = 'X']) =>
    ApiException(status, code, 'm');

void main() {
  group('retrying', () {
    test('retries 503 and returns the eventual value', () {
      fakeAsync((async) {
        var calls = 0;
        String? result;
        _guard()
            .retrying(() async {
              calls++;
              if (calls < 3) throw _api(503, 'SERVICE_UNAVAILABLE');
              return 'ok';
            })
            .then((v) => result = v);

        async.elapse(const Duration(seconds: 5));

        expect(result, 'ok');
        expect(calls, 3);
      });
    });

    test('gives up after maxAttempts with a mapped exception', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        _guard()
            .retrying<String>(() async {
              calls++;
              throw _api(503, 'SERVICE_UNAVAILABLE');
            })
            .then<void>((_) {}, onError: (Object e) => error = e);

        async.elapse(const Duration(seconds: 5));

        expect(calls, 3);
        expect(error, isA<ServiceUnavailableException>());
      });
    });

    test('does not retry definite rejections', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        _guard()
            .retrying<String>(() async {
              calls++;
              throw _api(422, 'INSUFFICIENT_FUNDS');
            })
            .then<void>((_) {}, onError: (Object e) => error = e);

        async.elapse(const Duration(seconds: 5));

        expect(calls, 1);
        expect(error, isA<BusinessRuleException>());
      });
    });
  });

  group('once', () {
    test('never retries a 503', () async {
      var calls = 0;

      await expectLater(
        _guard().once<String>(() async {
          calls++;
          throw _api(503, 'SERVICE_UNAVAILABLE');
        }),
        throwsA(isA<ServiceUnavailableException>()),
      );

      expect(calls, 1);
    });

    test('maps TimeoutException to RequestTimeoutException', () async {
      await expectLater(
        _guard().once<String>(() async => throw TimeoutException('t')),
        throwsA(isA<RequestTimeoutException>()),
      );
    });

    test('passes an AppException through unchanged', () async {
      const original = StorageException();

      await expectLater(
        _guard().once<String>(() async => throw original),
        throwsA(same(original)),
      );
    });

    test('wraps unknown errors (even Errors) in UnexpectedException', () async {
      await expectLater(
        _guard().once<String>(() async => throw StateError('bug')),
        throwsA(isA<UnexpectedException>()),
      );
    });

    test('maps synchronous throws from the call as well', () async {
      await expectLater(
        _guard().once<String>(() => throw _api(404, 'ORDER_NOT_FOUND')),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('guardStream', () {
    test('forwards data, maps errors, then closes', () async {
      final controller = StreamController<int>();
      final events = <Object>[];
      final done = Completer<void>();
      _guard()
          .guardStream(controller.stream)
          .listen(events.add, onError: events.add, onDone: done.complete);

      controller
        ..add(1)
        ..addError(ConnectionLostException())
        ..add(2);
      await controller.close();
      await done.future;

      expect(events[0], 1);
      expect(events[1], isA<StreamDisconnectedException>());
      expect(events[2], 2);
    });
  });
}
