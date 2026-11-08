import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/features/trading/data/order_repository_impl.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse_api/pulse_api.dart';

import '../../../support/fake_trading_remote_source.dart';

String _orderJson({
  String clientOrderId = 'c1',
  String status = 'FILLED',
  String symbol = 'AAPL',
}) =>
    '{"orderId":"o1","clientOrderId":"$clientOrderId","symbol":"$symbol",'
    '"side":"BUY","type":"MARKET","quantity":"10","status":"$status",'
    '"filledQuantity":"10","averagePrice":"228.52"}';

OrderRequest _request({String id = 'c1'}) => OrderRequest(
  clientOrderId: id,
  symbol: 'AAPL',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: Decimal.fromInt(10),
);

void main() {
  late FakeTradingRemoteSource source;
  late OrderRepositoryImpl repo;

  setUp(() {
    source = FakeTradingRemoteSource();
    repo = OrderRepositoryImpl(
      source: source,
      guard: RemoteCallGuard(
        mapper: const PulseApiExceptionMapper(),
        retryPolicy: RetryPolicy(
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 2),
        ),
      ),
    );
  });

  group('place', () {
    test(
      'sends the encoded request once and returns the confirmed order',
      () async {
        source.onPlaceOrder = (_) async => _orderJson();

        final order = await repo.place(_request());

        expect(order.status, OrderStatus.filled);
        expect(order.clientOrderId, 'c1');
        expect(source.count('placeOrder'), 1);
        final sent =
            jsonDecode(source.lastArguments.single! as String)
                as Map<String, Object?>;
        expect(sent['clientOrderId'], 'c1');
        expect(sent['quantity'], '10');
      },
    );

    test(
      'a 503 is NOT retried here (retry belongs to the order flow)',
      () async {
        source.onPlaceOrder = (_) async =>
            throw ApiException(503, 'SERVICE_UNAVAILABLE', 'm');

        await expectLater(
          repo.place(_request()),
          throwsA(isA<ServiceUnavailableException>()),
        );

        expect(source.count('placeOrder'), 1);
      },
    );

    test(
      'a timeout surfaces as RequestTimeoutException (outcome unknown)',
      () async {
        source.onPlaceOrder = (_) async => throw TimeoutException('t');

        await expectLater(
          repo.place(_request()),
          throwsA(isA<RequestTimeoutException>()),
        );
      },
    );

    test('definite rejections keep their business code', () async {
      source.onPlaceOrder = (_) async =>
          throw ApiException(422, 'INSUFFICIENT_FUNDS', 'm');

      await expectLater(
        repo.place(_request()),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.code,
            'code',
            'INSUFFICIENT_FUNDS',
          ),
        ),
      );
    });

    test('unreadable response means outcome UNKNOWN, not failure', () async {
      for (final body in ['oops', '[]', '{}', '{"clientOrderId":"c1"}']) {
        source.onPlaceOrder = (_) async => body;

        await expectLater(
          repo.place(_request()),
          throwsA(isA<RequestTimeoutException>()),
          reason: body,
        );
      }
    });

    test('response for a different clientOrderId is not trusted', () async {
      source.onPlaceOrder = (_) async => _orderJson(clientOrderId: 'other');

      await expectLater(
        repo.place(_request()),
        throwsA(isA<RequestTimeoutException>()),
      );
    });

    test(
      'unrecognised status is returned as unknown, never as filled',
      () async {
        source.onPlaceOrder = (_) async => _orderJson(status: 'PENDING_NEW');

        final order = await repo.place(_request());

        expect(order.status, OrderStatus.unknown);
      },
    );
  });

  group('getByClientOrderId', () {
    test('returns the order', () async {
      source.onGetOrder = (_) async => _orderJson();

      final order = await repo.getByClientOrderId('c1');

      expect(order.orderId, 'o1');
      expect(source.lastArguments.single, 'c1');
    });

    test('404 becomes NotFoundException ORDER_NOT_FOUND', () async {
      source.onGetOrder = (_) async =>
          throw ApiException(404, 'ORDER_NOT_FOUND', 'm');

      await expectLater(
        repo.getByClientOrderId('c1'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('retries a transient 503 (safe, read only)', () async {
      var calls = 0;
      source.onGetOrder = (_) async {
        calls++;
        if (calls == 1) throw ApiException(503, 'SERVICE_UNAVAILABLE', 'm');
        return _orderJson();
      };

      final order = await repo.getByClientOrderId('c1');

      expect(order.clientOrderId, 'c1');
      expect(calls, 2);
    });

    test('blank id fails validation without calling the server', () async {
      await expectLater(
        repo.getByClientOrderId('  '),
        throwsA(isA<ValidationException>()),
      );

      expect(source.count('getOrder'), 0);
    });
  });
}
