import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/utils/id_generator.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/entities/pending_order.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';

import '../../../support/fakes.dart';

class _MemoryLog implements RejectedOrderLog {
  final List<Order> saved = [];
  bool fails = false;

  @override
  Future<void> add(Order rejected) async {
    if (fails) throw const StorageException();
    saved.add(rejected);
  }

  @override
  Future<List<Order>> loadAll() async => saved;
}

class _SeqIds implements IdGenerator {
  int _n = 0;
  @override
  String generate() => 'id-${++_n}';
}

ValidOrder get _valid => ValidOrder(quantity: Decimal.fromInt(10));

OrderFlowSubmitted _submit() => OrderFlowSubmitted(
  symbol: 'AAPL',
  side: OrderSide.buy,
  type: OrderType.market,
  valid: _valid,
);

class _Harness {
  _Harness(
    List<Future<Order> Function(OrderRequest)> steps,
    this.store, {
    RejectedOrderLog? log,
  }) : placer = ScriptedPlacer(steps) {
    bloc = OrderFlowBloc(
      submitOrder: SubmitOrder(
        placer: placer,
        store: store,
        backoff: RetryPolicy(
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 1),
          random: Random(1),
        ),
        maxAttempts: 3,
      ),
      store: store,
      idGenerator: _SeqIds(),
      rejectedLog: log,
    );
    bloc.stream.listen(states.add);
  }

  final ScriptedPlacer placer;
  final InMemoryPendingOrderStore store;
  late final OrderFlowBloc bloc;
  final List<OrderFlowState> states = [];

  List<String> get names =>
      states.map((s) => s.runtimeType.toString()).toList();
}

void _run(
  List<Future<Order> Function(OrderRequest)> steps,
  void Function(_Harness h, FakeAsync async) body, {
  InMemoryPendingOrderStore? store,
  RejectedOrderLog? log,
}) {
  fakeAsync((async) {
    final h = _Harness(steps, store ?? InMemoryPendingOrderStore(), log: log);
    body(h, async);
    h.bloc.close();
    async.flushMicrotasks();
  });
}

void main() {
  test('starts locked (checking) and becomes idle when nothing is pending', () {
    _run([fills()], (h, async) {
      expect(h.bloc.state, isA<OrderFlowChecking>());
      expect(h.bloc.state.isLocked, isTrue);

      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();

      expect(h.bloc.state, isA<OrderFlowIdle>());
      expect(h.bloc.state.isLocked, isFalse);
    });
  });

  test('an unresolved earlier order for the same symbol blocks the ticket', () {
    final store = InMemoryPendingOrderStore();
    store.items['old'] = PendingOrder(
      request: testRequest(id: 'old'),
      createdAt: DateTime(2026),
      unresolved: true,
    );
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();

      expect(h.bloc.state, isA<OrderFlowUnresolved>());
      expect(
        (h.bloc.state as OrderFlowUnresolved).request.clientOrderId,
        'old',
      );
    }, store: store);
  });

  test('a pending order of ANOTHER symbol does not block', () {
    final store = InMemoryPendingOrderStore();
    store.items['x'] = PendingOrder(
      request: testRequest(id: 'x', symbol: 'MSFT'),
      createdAt: DateTime(2026),
    );
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();

      expect(h.bloc.state, isA<OrderFlowIdle>());
    }, store: store);
  });

  test('submit goes Sending -> Completed and the request carries a new id', () {
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();
      h.states.clear();

      h.bloc.add(_submit());
      async.flushMicrotasks();

      expect(h.names, ['OrderFlowSending', 'OrderFlowCompleted']);
      expect(
        (h.states.first as OrderFlowSending).request.clientOrderId,
        'id-1',
      );
      expect(h.state.isLocked, isFalse);
    });
  });

  test('double tap sends exactly ONE order (single flight)', () {
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();

      h.bloc
        ..add(_submit())
        ..add(_submit())
        ..add(_submit());
      async.flushMicrotasks();

      expect(h.placer.sent, hasLength(1));
    });
  });

  test('submitting again after completion is ignored', () {
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      h.bloc.add(_submit());
      async.flushMicrotasks();
      expect(h.bloc.state, isA<OrderFlowCompleted>());

      h.bloc.add(_submit());
      async.flushMicrotasks();

      expect(h.placer.sent, hasLength(1));
    });
  });

  test('is locked in every in-flight state (UI must be inert)', () {
    final req = testRequest();
    expect(OrderFlowSending(req).isLocked, isTrue);
    expect(OrderFlowResolving(req, 1).isLocked, isTrue);
    expect(OrderFlowUnresolved(req).isLocked, isTrue);
    expect(const OrderFlowChecking().isLocked, isTrue);
    expect(const OrderFlowIdle().isLocked, isFalse);
  });

  test('timeout is shown as Resolving, then Completed with the SAME id', () {
    _run([throwsAs(const RequestTimeoutException()), fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();
      h.states.clear();

      h.bloc.add(_submit());
      async.elapse(const Duration(seconds: 10));

      expect(h.names, [
        'OrderFlowSending',
        'OrderFlowResolving',
        'OrderFlowCompleted',
      ]);
      expect(h.placer.sent.map((r) => r.clientOrderId).toSet(), {'id-1'});
      expect(h.states.whereType<OrderFlowRejected>(), isEmpty);
    });
  });

  test('exhausted retries end Unresolved, then a manual check resolves it', () {
    _run(
      [
        throwsAs(const RequestTimeoutException()),
        throwsAs(const RequestTimeoutException()),
        throwsAs(const RequestTimeoutException()),
        fills(),
      ],
      (h, async) {
        h.bloc.add(const OrderFlowStarted('AAPL'));
        h.bloc.add(_submit());
        async.elapse(const Duration(seconds: 10));
        expect(h.bloc.state, isA<OrderFlowUnresolved>());
        expect(h.store.items['id-1']!.unresolved, isTrue);

        h.bloc.add(const OrderFlowStatusCheckRequested());
        async.elapse(const Duration(seconds: 10));

        expect(h.bloc.state, isA<OrderFlowCompleted>());
        expect(h.placer.sent.map((r) => r.clientOrderId).toSet(), {'id-1'});
      },
    );
  });

  test('status check is ignored unless the order is unresolved', () {
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      async.flushMicrotasks();

      h.bloc.add(const OrderFlowStatusCheckRequested());
      async.flushMicrotasks();

      expect(h.placer.sent, isEmpty);
    });
  });

  test(
    'rejection is shown, then the user may edit and submit with a NEW id',
    () {
      _run(
        [
          throwsAs(const BusinessRuleException(code: 'INSUFFICIENT_FUNDS')),
          fills(),
        ],
        (h, async) {
          h.bloc.add(const OrderFlowStarted('AAPL'));
          h.bloc.add(_submit());
          async.flushMicrotasks();
          expect(h.bloc.state, isA<OrderFlowRejected>());
          expect(h.bloc.state.isLocked, isFalse);

          h.bloc.add(_submit());
          async.flushMicrotasks();

          expect(h.bloc.state, isA<OrderFlowCompleted>());
          expect(h.placer.sent.map((r) => r.clientOrderId), ['id-1', 'id-2']);
        },
      );
    },
  );

  group('rejected order history', () {
    test('a server refusal is recorded with its reason', () {
      final log = _MemoryLog();
      _run(
        [throwsAs(const BusinessRuleException(code: 'INSUFFICIENT_FUNDS'))],
        (h, async) {
          h.bloc.add(const OrderFlowStarted('AAPL'));
          h.bloc.add(_submit());
          async.flushMicrotasks();

          final saved = log.saved.single;
          expect(saved.status, OrderStatus.rejected);
          expect(saved.rejectReason, 'INSUFFICIENT_FUNDS');
          expect(saved.symbol, 'AAPL');
          expect(saved.clientOrderId, 'id-1');
        },
        log: log,
      );
    });

    test('a failing log never blocks showing the rejection', () {
      final log = _MemoryLog()..fails = true;
      _run([throwsAs(const BusinessRuleException(code: 'TRADING_HALTED'))], (
        h,
        async,
      ) {
        h.bloc.add(const OrderFlowStarted('AAPL'));
        h.bloc.add(_submit());
        async.flushMicrotasks();

        expect(h.bloc.state, isA<OrderFlowRejected>());
      }, log: log);
    });

    test('a fill is not recorded as a rejection', () {
      final log = _MemoryLog();
      _run([fills()], (h, async) {
        h.bloc.add(const OrderFlowStarted('AAPL'));
        h.bloc.add(_submit());
        async.flushMicrotasks();

        expect(log.saved, isEmpty);
      }, log: log);
    });
  });

  test('dismissing a rejection returns to idle', () {
    _run([throwsAs(const BusinessRuleException(code: 'X'))], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      h.bloc.add(_submit());
      async.flushMicrotasks();

      h.bloc.add(const OrderFlowRejectionDismissed());
      async.flushMicrotasks();

      expect(h.bloc.state, isA<OrderFlowIdle>());
    });
  });

  test('if the attempt cannot be persisted nothing is sent and it says so', () {
    final store = InMemoryPendingOrderStore()
      ..saveError = const StorageException();
    _run([fills()], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      h.bloc.add(_submit());
      async.flushMicrotasks();

      expect(h.placer.sent, isEmpty);
      expect(h.bloc.state, isA<OrderFlowRejected>());
      expect(
        (h.bloc.state as OrderFlowRejected).error,
        isA<StorageException>(),
      );
    }, store: store);
  });

  test('closing the bloc while resolving does not throw', () {
    _run([throwsAs(const RequestTimeoutException())], (h, async) {
      h.bloc.add(const OrderFlowStarted('AAPL'));
      h.bloc.add(_submit());
      async.elapse(const Duration(milliseconds: 150));

      h.bloc.close();

      expect(() => async.elapse(const Duration(seconds: 10)), returnsNormally);
    });
  });
}

extension on _Harness {
  OrderFlowState get state => bloc.state;
}
