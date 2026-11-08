import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/core/utils/id_generator.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/repositories/pending_order_store.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';
import 'package:pulse/features/trading/domain/use_cases/submit_order.dart';

sealed class OrderFlowEvent {
  const OrderFlowEvent();
}

/// Looks for an earlier unresolved order of this symbol (ORD-07).
class OrderFlowStarted extends OrderFlowEvent {
  const OrderFlowStarted(this.symbol);

  final String symbol;
}

class OrderFlowSubmitted extends OrderFlowEvent {
  const OrderFlowSubmitted({
    required this.symbol,
    required this.side,
    required this.type,
    required this.valid,
  });

  final String symbol;
  final OrderSide side;
  final OrderType type;
  final ValidOrder valid;
}

class OrderFlowStatusCheckRequested extends OrderFlowEvent {
  const OrderFlowStatusCheckRequested();
}

class OrderFlowRejectionDismissed extends OrderFlowEvent {
  const OrderFlowRejectionDismissed();
}

sealed class OrderFlowState extends Equatable {
  const OrderFlowState();

  /// While locked, the ticket must be fully inert (ORD-01).
  bool get isLocked => switch (this) {
    OrderFlowChecking() ||
    OrderFlowSending() ||
    OrderFlowResolving() ||
    OrderFlowUnresolved() => true,
    OrderFlowIdle() || OrderFlowCompleted() || OrderFlowRejected() => false,
  };

  @override
  List<Object?> get props => const [];
}

class OrderFlowChecking extends OrderFlowState {
  const OrderFlowChecking();
}

class OrderFlowIdle extends OrderFlowState {
  const OrderFlowIdle();
}

class OrderFlowSending extends OrderFlowState {
  const OrderFlowSending(this.request);

  final OrderRequest request;

  @override
  List<Object?> get props => [request];
}

/// Outcome unknown; the same request is being re-sent (never "failed").
class OrderFlowResolving extends OrderFlowState {
  const OrderFlowResolving(this.request, this.attempt);

  final OrderRequest request;
  final int attempt;

  @override
  List<Object?> get props => [request, attempt];
}

/// Automatic resolution gave up. Only the user may ask again.
class OrderFlowUnresolved extends OrderFlowState {
  const OrderFlowUnresolved(this.request);

  final OrderRequest request;

  @override
  List<Object?> get props => [request];
}

class OrderFlowCompleted extends OrderFlowState {
  const OrderFlowCompleted(this.order);

  final Order order;

  @override
  List<Object?> get props => [order];
}

/// Definitive refusal, or the order was never sent.
class OrderFlowRejected extends OrderFlowState {
  const OrderFlowRejected(this.error);

  final AppException error;

  @override
  List<Object?> get props => [error.code, error.runtimeType];
}

/// Single-flight order submission state machine (ORD-01..06).
class OrderFlowBloc extends Bloc<OrderFlowEvent, OrderFlowState> {
  OrderFlowBloc({
    required SubmitOrder submitOrder,
    required PendingOrderStore store,
    required IdGenerator idGenerator,
    RejectedOrderLog? rejectedLog,
    Clock clock = const SystemClock(),
  }) : _rejectedLog = rejectedLog,
       _clock = clock,
       _submitOrder = submitOrder,
       _store = store,
       _idGenerator = idGenerator,
       super(const OrderFlowChecking()) {
    on<OrderFlowStarted>(_onStarted, transformer: sequential());
    on<OrderFlowSubmitted>(_onSubmitted, transformer: droppable());
    on<OrderFlowStatusCheckRequested>(_onCheck, transformer: droppable());
    on<OrderFlowRejectionDismissed>(_onDismissed);
  }

  final SubmitOrder _submitOrder;
  final PendingOrderStore _store;
  final IdGenerator _idGenerator;
  final RejectedOrderLog? _rejectedLog;
  final Clock _clock;

  Future<void> _onStarted(
    OrderFlowStarted event,
    Emitter<OrderFlowState> emit,
  ) async {
    try {
      final pending = await _store.loadAll();
      final earlier = pending.where((p) => p.request.symbol == event.symbol);
      emit(
        earlier.isEmpty
            ? const OrderFlowIdle()
            : OrderFlowUnresolved(earlier.first.request),
      );
    } on AppException {
      // Cannot read the store: submitting would fail to persist and send
      // nothing, so it is safe to allow editing.
      emit(const OrderFlowIdle());
    }
  }

  Future<void> _onSubmitted(
    OrderFlowSubmitted event,
    Emitter<OrderFlowState> emit,
  ) async {
    if (state is! OrderFlowIdle && state is! OrderFlowRejected) return;
    final request = OrderRequest(
      clientOrderId: _idGenerator.generate(),
      symbol: event.symbol,
      side: event.side,
      type: event.type,
      quantity: event.valid.quantity,
      limitPrice: event.valid.limitPrice,
    );
    emit(OrderFlowSending(request));
    try {
      final outcome = await _submitOrder(
        request,
        onResolving: (attempt) {
          if (!emit.isDone) emit(OrderFlowResolving(request, attempt));
        },
      );
      await _recordRejection(request, outcome);
      if (!emit.isDone) emit(_stateFor(outcome));
    } on AppException catch (e) {
      // Nothing was sent (could not persist the attempt).
      if (!emit.isDone) emit(OrderFlowRejected(e));
    }
  }

  Future<void> _onCheck(
    OrderFlowStatusCheckRequested event,
    Emitter<OrderFlowState> emit,
  ) async {
    final current = state;
    if (current is! OrderFlowUnresolved) return;
    final request = current.request;
    emit(OrderFlowResolving(request, 0));
    final outcome = await _submitOrder.resolve(
      request,
      onResolving: (attempt) {
        if (!emit.isDone) emit(OrderFlowResolving(request, attempt));
      },
    );
    if (!emit.isDone) emit(_stateFor(outcome));
  }

  /// The server does not list refused orders, so the app keeps its own
  /// record for the order history. Failing to write it never blocks the user.
  Future<void> _recordRejection(
    OrderRequest request,
    SubmitOutcome outcome,
  ) async {
    final log = _rejectedLog;
    if (log == null || outcome is! OrderRejectedOutcome) return;
    final error = outcome.error;
    try {
      await log.add(
        Order(
          orderId: '',
          clientOrderId: request.clientOrderId,
          symbol: request.symbol,
          side: request.side,
          type: request.type,
          quantity: request.quantity,
          status: OrderStatus.rejected,
          filledQuantity: Decimal.zero,
          limitPrice: request.limitPrice,
          rejectReason: error.code,
          createdAt: _clock.now().toUtc(),
        ),
      );
    } on AppException {
      // History is a convenience; the rejection itself is still shown.
    }
  }

  void _onDismissed(
    OrderFlowRejectionDismissed event,
    Emitter<OrderFlowState> emit,
  ) {
    if (state is OrderFlowRejected) emit(const OrderFlowIdle());
  }

  OrderFlowState _stateFor(SubmitOutcome outcome) {
    return switch (outcome) {
      OrderConfirmed(:final order) => OrderFlowCompleted(order),
      OrderRejectedOutcome(:final error) => OrderFlowRejected(error),
      OrderUnresolved(:final request) => OrderFlowUnresolved(request),
    };
  }
}
