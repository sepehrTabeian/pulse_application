import 'package:flutter/material.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/unit_label.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Explains clearly what happened to the order (Must #3, #4).
/// Renders nothing for the idle states.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({
    required this.state,
    required this.instrument,
    required this.resolver,
    required this.onCheckStatus,
    required this.onDone,
    super.key,
  });

  final OrderFlowState state;
  final Instrument instrument;
  final ErrorMessageResolver resolver;
  final VoidCallback onCheckStatus;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return switch (state) {
      OrderFlowChecking() => _card(
        context,
        icon: Icons.hourglass_top,
        title: l10n.orderChecking,
        busy: true,
      ),
      OrderFlowIdle() => const SizedBox.shrink(),
      OrderFlowSending() => _card(
        context,
        icon: Icons.send,
        title: l10n.orderSending,
        busy: true,
      ),
      OrderFlowResolving(:final attempt) => _card(
        context,
        icon: Icons.sync,
        title: l10n.orderResolving,
        body: attempt > 0
            ? l10n.orderResolvingAttempt(attempt.toString())
            : null,
        busy: true,
      ),
      OrderFlowUnresolved() => _card(
        context,
        icon: Icons.help_outline,
        title: l10n.orderUnresolvedTitle,
        body: l10n.orderUnresolvedBody,
        action: FilledButton.tonal(
          onPressed: onCheckStatus,
          child: Text(l10n.actionCheckOrderStatus),
        ),
        color: theme.colorScheme.tertiaryContainer,
      ),
      OrderFlowCompleted(:final order) => _completed(context, order),
      OrderFlowRejected(:final error) => _card(
        context,
        icon: Icons.error_outline,
        title: l10n.orderRejectedTitle,
        body: resolver.resolve(error, l10n),
        color: theme.colorScheme.errorContainer,
      ),
    };
  }

  Widget _completed(BuildContext context, Order order) {
    final l10n = AppLocalizations.of(context);
    final digits = instrument.tickSize.scale;
    final filled = order.status == OrderStatus.filled;
    final price = order.averagePrice;
    final body = filled
        ? l10n.orderFilledBody(
            DecimalFormatter.format(
              order.filledQuantity,
              fractionDigits: instrument.lotSize.scale,
            ),
            instrumentUnitLabel(instrument.unit, l10n) ?? '',
            order.symbol,
            price == null
                ? '—'
                : DecimalFormatter.format(price, fractionDigits: digits),
          )
        : l10n.orderWorkingBody;
    return _card(
      context,
      icon: filled ? Icons.check_circle_outline : Icons.schedule,
      title: filled ? l10n.orderFilledTitle : l10n.orderWorkingTitle,
      body: body,
      action: FilledButton.tonal(
        onPressed: onDone,
        child: Text(l10n.actionBackToList),
      ),
      color: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? body,
    Widget? action,
    bool busy = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        color: color,
        margin: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(icon),
                  const SizedBox(width: PulseSpacing.sm),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              if (body != null) ...[
                const SizedBox(height: PulseSpacing.sm),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
              if (action != null) ...[
                const SizedBox(height: PulseSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
