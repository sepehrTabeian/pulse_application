import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/format/number_input.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/adaptive_layout.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/candles/presentation/widgets/candle_section.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/unit_label.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/prices/presentation/widgets/feed_status_banner.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/domain/services/max_order_quantity.dart';
import 'package:pulse/features/trading/domain/services/order_cost_estimator.dart';
import 'package:pulse/features/trading/domain/services/order_validator.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/cubit/ticket_form_cubit.dart';
import 'package:pulse/features/trading/presentation/validation_messages.dart';
import 'package:pulse/features/trading/presentation/widgets/order_status_card.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Buy/sell ticket (Must #3, #4) with an optional price chart.
///
/// * phone (`embedded: false`): a full screen that cannot be left while an
///   order is in flight (ORD-01);
/// * tablet (`embedded: true`): the detail pane of the two-pane layout. It
///   reports lock changes so the list can refuse to switch symbol meanwhile.
class TicketPage extends StatelessWidget {
  const TicketPage({
    required this.instrument,
    required this.orderFlow,
    required this.resolver,
    this.candles,
    this.embedded = false,
    this.onLockChanged,
    super.key,
  });

  final Instrument instrument;
  final OrderFlowBloc orderFlow;
  final ErrorMessageResolver resolver;
  final CandlesCubit? candles;
  final bool embedded;
  final ValueChanged<bool>? onLockChanged;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TicketFormCubit>(
          create: (_) => TicketFormCubit(instrument: instrument),
        ),
        BlocProvider<OrderFlowBloc>.value(value: orderFlow),
        if (candles != null) BlocProvider<CandlesCubit>.value(value: candles!),
      ],
      child: _TicketScaffold(
        instrument: instrument,
        resolver: resolver,
        hasChart: candles != null,
        embedded: embedded,
        onLockChanged: onLockChanged,
      ),
    );
  }
}

class _TicketScaffold extends StatelessWidget {
  const _TicketScaffold({
    required this.instrument,
    required this.resolver,
    required this.hasChart,
    required this.embedded,
    required this.onLockChanged,
  });

  final Instrument instrument;
  final ErrorMessageResolver resolver;
  final bool hasChart;
  final bool embedded;
  final ValueChanged<bool>? onLockChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<OrderFlowBloc, OrderFlowState>(
          listenWhen: (a, b) =>
              b is OrderFlowCompleted && a is! OrderFlowCompleted,
          // ORD-08: cash/positions come from the server after a fill.
          listener: (context, _) => context.read<PortfolioCubit>().load(),
        ),
        BlocListener<OrderFlowBloc, OrderFlowState>(
          listenWhen: (a, b) => a.isLocked != b.isLocked,
          listener: (_, state) => onLockChanged?.call(state.isLocked),
        ),
        BlocListener<PriceFeedCubit, PriceFeedState>(
          listener: (context, feed) {
            final quote = feed.quotes[instrument.symbol];
            context.read<TicketFormCubit>().updateMarket(quote, feed.status);
            // The chart's newest bar follows the live price.
            if (hasChart && quote != null) {
              context.read<CandlesCubit>().applyLivePrice(quote.last);
            }
          },
        ),
      ],
      child: BlocBuilder<OrderFlowBloc, OrderFlowState>(
        builder: (context, flow) {
          final body = _TicketBody(
            instrument: instrument,
            resolver: resolver,
            flow: flow,
            hasChart: hasChart,
            chartHeight: embedded ? 280 : 200,
          );
          if (embedded) {
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AdaptiveLayout.maxDetailContentWidth,
                  ),
                  child: body,
                ),
              ),
            );
          }
          return PopScope(
            canPop: !flow.isLocked,
            child: Scaffold(
              appBar: AppBar(
                title: Text('${l10n.ticketTitle} · ${instrument.symbol}'),
                automaticallyImplyLeading: !flow.isLocked,
              ),
              body: body,
            ),
          );
        },
      ),
    );
  }
}

class _TicketBody extends StatefulWidget {
  const _TicketBody({
    required this.instrument,
    required this.resolver,
    required this.flow,
    required this.hasChart,
    required this.chartHeight,
  });

  final Instrument instrument;
  final ErrorMessageResolver resolver;
  final OrderFlowState flow;
  final bool hasChart;
  final double chartHeight;

  @override
  State<_TicketBody> createState() => _TicketBodyState();
}

class _TicketBodyState extends State<_TicketBody> {
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _limitPrice = TextEditingController();
  static final List<TextInputFormatter> _numberFormatters = [
    FilteringTextInputFormatter.allow(RegExp('[0-9۰-۹٠-٩.٫]')),
    LengthLimitingTextInputFormatter(NumberInput.maxLength),
  ];

  @override
  void initState() {
    super.initState();
    // Seed the form with the current feed (the page may open mid-session).
    final feed = context.read<PriceFeedCubit>().state;
    context.read<TicketFormCubit>().updateMarket(
      feed.quotes[widget.instrument.symbol],
      feed.status,
    );
    context.read<OrderFlowBloc>().add(
      OrderFlowStarted(widget.instrument.symbol),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _limitPrice.dispose();
    super.dispose();
  }

  void _dismissRejection() =>
      context.read<OrderFlowBloc>().add(const OrderFlowRejectionDismissed());

  void _submit(TicketFormState form) {
    final cubit = context.read<TicketFormCubit>();
    final valid = form.valid;
    if (valid == null || form.isFeedOffline) {
      cubit.markSubmitAttempted();
      return;
    }
    context.read<OrderFlowBloc>().add(
      OrderFlowSubmitted(
        symbol: widget.instrument.symbol,
        side: form.side,
        type: form.type,
        valid: valid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locked = widget.flow.isLocked;
    final inFlight =
        widget.flow is OrderFlowSending || widget.flow is OrderFlowResolving;
    return BlocBuilder<TicketFormCubit, TicketFormState>(
      builder: (context, form) {
        final canTap =
            !locked && widget.instrument.tradable && !form.isFeedOffline;
        return AbsorbPointer(
          absorbing: false,
          child: ListView(
            padding: const EdgeInsets.all(PulseSpacing.md),
            children: [
              _InstrumentHeader(instrument: widget.instrument),
              if (widget.hasChart) ...[
                const SizedBox(height: PulseSpacing.sm),
                CandleSection(
                  instrument: widget.instrument,
                  resolver: widget.resolver,
                  chartHeight: widget.chartHeight,
                ),
              ],
              const FeedStatusBanner(hasSymbols: true),
              if (!widget.instrument.tradable)
                _InlineNote(
                  icon: Icons.pause_circle_outline,
                  text: l10n.errorTradingHalted,
                ),
              if (form.isFeedOffline && widget.instrument.tradable)
                _InlineNote(
                  icon: Icons.cloud_off,
                  text: l10n.ticketOfflineBlocked,
                ),
              const SizedBox(height: PulseSpacing.md),
              SegmentedButton<OrderSide>(
                segments: [
                  ButtonSegment(
                    value: OrderSide.buy,
                    label: Text(l10n.sideBuy),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: OrderSide.sell,
                    label: Text(l10n.sideSell),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {form.side},
                onSelectionChanged: locked
                    ? null
                    : (s) {
                        _dismissRejection();
                        context.read<TicketFormCubit>().setSide(s.first);
                      },
              ),
              const SizedBox(height: PulseSpacing.sm),
              SegmentedButton<OrderType>(
                segments: [
                  ButtonSegment(
                    value: OrderType.market,
                    label: Text(l10n.typeMarket),
                  ),
                  ButtonSegment(
                    value: OrderType.limit,
                    label: Text(l10n.typeLimit),
                  ),
                ],
                selected: {form.type},
                onSelectionChanged: locked
                    ? null
                    : (s) {
                        _dismissRejection();
                        context.read<TicketFormCubit>().setType(s.first);
                      },
              ),
              const SizedBox(height: PulseSpacing.md),
              _NumberField(
                controller: _quantity,
                label: _quantityLabel(widget.instrument.unit, l10n),
                suffixText: instrumentUnitLabel(widget.instrument.unit, l10n),
                enabled: !locked,
                formatters: _numberFormatters,
                error: _errorText(form, OrderField.quantity, l10n),
                onChanged: (text) {
                  _dismissRejection();
                  context.read<TicketFormCubit>().setQuantity(text);
                },
              ),
              _AvailabilityLine(
                instrument: widget.instrument,
                enabled: !locked,
                onFill: (text) {
                  _quantity.text = text;
                  _dismissRejection();
                  context.read<TicketFormCubit>().setQuantity(text);
                },
              ),
              if (form.type == OrderType.limit) ...[
                const SizedBox(height: PulseSpacing.md),
                _NumberField(
                  controller: _limitPrice,
                  label: l10n.limitPriceLabel,
                  enabled: !locked,
                  formatters: _numberFormatters,
                  error: _errorText(form, OrderField.limitPrice, l10n),
                  onChanged: (text) {
                    _dismissRejection();
                    context.read<TicketFormCubit>().setLimitPrice(text);
                  },
                ),
              ],
              const SizedBox(height: PulseSpacing.md),
              _EstimateView(form: form, instrument: widget.instrument),
              OrderStatusCard(
                state: widget.flow,
                instrument: widget.instrument,
                resolver: widget.resolver,
                onCheckStatus: () => context.read<OrderFlowBloc>().add(
                  const OrderFlowStatusCheckRequested(),
                ),
                onDone: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: PulseSpacing.md),
              if (widget.flow is! OrderFlowCompleted &&
                  widget.flow is! OrderFlowUnresolved)
                PulsePrimaryButton(
                  label: l10n.submitOrder,
                  pendingLabel: l10n.orderSending,
                  isPending: inFlight,
                  onPressed: canTap ? () => _submit(form) : null,
                ),
            ],
          ),
        );
      },
    );
  }

  String? _errorText(
    TicketFormState form,
    OrderField field,
    AppLocalizations l10n,
  ) {
    final rule = form.visibleError(field);
    return rule == null
        ? null
        : ValidationMessages.of(rule, l10n, widget.instrument);
  }
}

class _InstrumentHeader extends StatelessWidget {
  const _InstrumentHeader({required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final digits = instrument.tickSize.scale;
    return BlocBuilder<PriceFeedCubit, PriceFeedState>(
      buildWhen: (a, b) =>
          a.quotes[instrument.symbol] != b.quotes[instrument.symbol] ||
          a.status != b.status,
      builder: (context, feed) {
        final halted = !instrument.tradable;
        final last = halted
            ? instrument.prevClose
            : feed.quotes[instrument.symbol]?.last;
        final stale =
            feed.status == FeedStatus.stale ||
            feed.status == FeedStatus.offline;
        return Row(
          children: [
            Expanded(
              child: Text(instrument.name, style: theme.textTheme.titleMedium),
            ),
            Opacity(
              opacity: stale && !halted ? 0.55 : 1,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  last == null
                      ? '—'
                      : DecimalFormatter.format(last, fractionDigits: digits),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            if (halted) ...[
              const SizedBox(width: PulseSpacing.sm),
              Text(l10n.haltedBadge),
            ] else if (stale) ...[
              const SizedBox(width: PulseSpacing.sm),
              Text(l10n.staleBadge),
            ],
          ],
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.formatters,
    required this.error,
    required this.onChanged,
    this.suffixText,
  });

  final String? suffixText;
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final List<TextInputFormatter> formatters;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _EstimateView extends StatelessWidget {
  const _EstimateView({required this.form, required this.instrument});

  final TicketFormState form;
  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final estimate = form.estimate;
    if (form.valid == null) return const SizedBox.shrink();
    if (estimate == null) {
      return Text(l10n.estimatedUnavailable, style: theme.textTheme.bodySmall);
    }
    final basis = switch (estimate.basis) {
      CostBasis.ask => l10n.costBasisAsk,
      CostBasis.bid => l10n.costBasisBid,
      CostBasis.limit => l10n.costBasisLimit,
      CostBasis.last => l10n.costBasisLast,
    };
    return Opacity(
      opacity: form.isStale ? 0.6 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.estimatedAmount, style: theme.textTheme.labelLarge),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${DecimalFormatter.format(estimate.amount)} ${instrument.currency}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(basis, style: theme.textTheme.bodySmall),
              if (form.isStale)
                Text(l10n.estimateStaleNote, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PulseSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// "Quantity (unit)" so the unit is visible even before typing.
String _quantityLabel(String unit, AppLocalizations l10n) {
  final label = instrumentUnitLabel(unit, l10n);
  return label == null ? l10n.quantityLabel : '${l10n.quantityLabel} ($label)';
}

/// What the user can still do: when buying, the USD they can spend (and the
/// most they can afford); when selling, the amount they hold. All figures
/// come from the server's account (SSOT-01); [onFill] writes the maximum
/// into the quantity field.
class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({
    required this.instrument,
    required this.enabled,
    required this.onFill,
  });

  final Instrument instrument;
  final bool enabled;
  final ValueChanged<String> onFill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = context.select<PortfolioCubit, Account?>(
      (c) => c.state.account,
    );
    if (account == null) return const SizedBox.shrink();
    final side = context.select<TicketFormCubit, OrderSide>(
      (c) => c.state.side,
    );
    final quote = context.select<PriceFeedCubit, PriceQuote?>(
      (c) => c.state.quotes[instrument.symbol],
    );
    final unit = instrumentUnitLabel(instrument.unit, l10n) ?? '';
    final lotDigits = instrument.lotSize.scale;
    String qty(Decimal v) =>
        DecimalFormatter.format(v, fractionDigits: lotDigits);
    final held = account.positions
        .where((p) => p.symbol == instrument.symbol)
        .map((p) => p.quantity)
        .fold(Decimal.zero, (a, b) => a + b);

    final lines = <String>[];
    Decimal? max;
    if (side == OrderSide.buy) {
      max = MaxOrderQuantity.forBuy(
        cash: account.cash,
        price: quote?.ask ?? quote?.last,
        lotSize: instrument.lotSize,
      );
      lines.add(
        l10n.availableToBuy(
          '${DecimalFormatter.format(account.cash)} ${account.currency}',
        ),
      );
      if (max != null) lines.add(l10n.availableToBuyMax(qty(max), unit));
      lines.add(
        held > Decimal.zero
            ? l10n.holdingLabel(qty(held), unit)
            : l10n.holdingNone,
      );
    } else {
      max = MaxOrderQuantity.forSell(held: held, lotSize: instrument.lotSize);
      lines.add(
        max > Decimal.zero
            ? l10n.availableToSell(qty(max), unit)
            : l10n.availableToSellNone,
      );
    }
    final fillable = max != null && max > Decimal.zero;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: PulseSpacing.sm,
        top: PulseSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(line.trim(), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (fillable)
            TextButton(
              onPressed: enabled ? () => onFill(qty(max!)) : null,
              child: Text(l10n.actionMax),
            ),
        ],
      ),
    );
  }
}
