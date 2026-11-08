import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/services/order_cost_estimator.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';

class TicketFormState extends Equatable {
  const TicketFormState({
    required this.side,
    required this.type,
    required this.quantityText,
    required this.limitPriceText,
    required this.errors,
    required this.touchedQuantity,
    required this.touchedLimitPrice,
    required this.submitAttempted,
    required this.feedStatus,
    this.valid,
    this.estimate,
  });

  final OrderSide side;
  final OrderType type;
  final String quantityText;
  final String limitPriceText;
  final Map<OrderField, ValidationRule> errors;
  final bool touchedQuantity;
  final bool touchedLimitPrice;
  final bool submitAttempted;
  final FeedStatus feedStatus;

  /// Non-null only when every rule passes.
  final ValidOrder? valid;
  final CostEstimate? estimate;

  /// The feed is down: do not allow new orders (Q7).
  bool get isFeedOffline => feedStatus == FeedStatus.offline;

  bool get isStale =>
      feedStatus == FeedStatus.stale || feedStatus == FeedStatus.offline;

  bool get canSubmit => valid != null && !isFeedOffline;

  ValidationRule? visibleError(OrderField field) {
    final shown = switch (field) {
      OrderField.quantity => touchedQuantity || submitAttempted,
      OrderField.limitPrice => touchedLimitPrice || submitAttempted,
      OrderField.instrument => true,
    };
    return shown ? errors[field] : null;
  }

  @override
  List<Object?> get props => [
    side,
    type,
    quantityText,
    limitPriceText,
    errors,
    touchedQuantity,
    touchedLimitPrice,
    submitAttempted,
    feedStatus,
    valid?.quantity,
    valid?.limitPrice,
    estimate,
  ];
}

/// Draft of the order ticket: validation + estimated cost (VAL-01..03).
class TicketFormCubit extends Cubit<TicketFormState> {
  TicketFormCubit({
    required this.instrument,
    OrderValidator validator = const OrderValidator(),
    OrderCostEstimator estimator = const OrderCostEstimator(),
  }) : _validator = validator,
       _estimator = estimator,
       super(
         _build(
           instrument: instrument,
           validator: validator,
           estimator: estimator,
           side: OrderSide.buy,
           type: OrderType.market,
           quantityText: '',
           limitPriceText: '',
           touchedQuantity: false,
           touchedLimitPrice: false,
           submitAttempted: false,
           feedStatus: FeedStatus.connecting,
           quote: null,
         ),
       );

  final Instrument instrument;
  final OrderValidator _validator;
  final OrderCostEstimator _estimator;
  PriceQuote? _quote;

  void setSide(OrderSide side) => _update(side: side);

  void setType(OrderType type) => _update(type: type);

  void setQuantity(String text) =>
      _update(quantityText: text, touchedQuantity: true);

  void setLimitPrice(String text) =>
      _update(limitPriceText: text, touchedLimitPrice: true);

  /// Called by the page whenever the live price or feed health changes.
  void updateMarket(PriceQuote? quote, FeedStatus status) {
    _quote = quote;
    _update(feedStatus: status);
  }

  /// Shows every error (used when the user taps submit while invalid).
  void markSubmitAttempted() => _update(submitAttempted: true);

  void _update({
    OrderSide? side,
    OrderType? type,
    String? quantityText,
    String? limitPriceText,
    bool? touchedQuantity,
    bool? touchedLimitPrice,
    bool? submitAttempted,
    FeedStatus? feedStatus,
  }) {
    final current = state;
    emit(
      _build(
        instrument: instrument,
        validator: _validator,
        estimator: _estimator,
        side: side ?? current.side,
        type: type ?? current.type,
        quantityText: quantityText ?? current.quantityText,
        limitPriceText: limitPriceText ?? current.limitPriceText,
        touchedQuantity: touchedQuantity ?? current.touchedQuantity,
        touchedLimitPrice: touchedLimitPrice ?? current.touchedLimitPrice,
        submitAttempted: submitAttempted ?? current.submitAttempted,
        feedStatus: feedStatus ?? current.feedStatus,
        quote: _quote,
      ),
    );
  }

  static TicketFormState _build({
    required Instrument instrument,
    required OrderValidator validator,
    required OrderCostEstimator estimator,
    required OrderSide side,
    required OrderType type,
    required String quantityText,
    required String limitPriceText,
    required bool touchedQuantity,
    required bool touchedLimitPrice,
    required bool submitAttempted,
    required FeedStatus feedStatus,
    required PriceQuote? quote,
  }) {
    final validation = validator.validate(
      instrument: instrument,
      type: type,
      quantityText: quantityText,
      limitPriceText: limitPriceText,
    );
    final ValidOrder? valid = validation is ValidOrder ? validation : null;
    final errors = validation is InvalidOrder
        ? validation.errors
        : const <OrderField, ValidationRule>{};
    return TicketFormState(
      side: side,
      type: type,
      quantityText: quantityText,
      limitPriceText: limitPriceText,
      errors: errors,
      touchedQuantity: touchedQuantity,
      touchedLimitPrice: touchedLimitPrice,
      submitAttempted: submitAttempted,
      feedStatus: feedStatus,
      valid: valid,
      estimate: _estimate(
        estimator,
        side,
        type,
        valid,
        errors,
        quantityText,
        limitPriceText,
        quote,
      ),
    );
  }

  /// The estimate is shown as soon as quantity (and price for LIMIT) are
  /// readable, even if other rules fail, so the user sees the cost early.
  static CostEstimate? _estimate(
    OrderCostEstimator estimator,
    OrderSide side,
    OrderType type,
    ValidOrder? valid,
    Map<OrderField, ValidationRule> errors,
    String quantityText,
    String limitPriceText,
    PriceQuote? quote,
  ) {
    if (valid != null) {
      return estimator.estimate(
        side: side,
        type: type,
        quantity: valid.quantity,
        limitPrice: valid.limitPrice,
        quote: quote,
      );
    }
    return null;
  }
}

/// Convenience for tests and widgets.
extension TicketFormX on TicketFormState {
  Decimal? get quantity => valid?.quantity;
}
