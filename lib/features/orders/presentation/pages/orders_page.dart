import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/unit_label.dart';
import 'package:pulse/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// History of all orders, filtered by status and by stocks/crypto.
class OrdersPage extends StatelessWidget {
  const OrdersPage({required this.resolver, super.key});

  final ErrorMessageResolver resolver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<OrdersCubit, OrdersState>(
      listenWhen: (a, b) =>
          b.refreshError != null && a.refreshError != b.refreshError,
      listener: (context, state) {
        final error = state.refreshError;
        if (error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(resolver.resolve(error, l10n))),
          );
        context.read<OrdersCubit>().clearRefreshError();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.ordersTitle)),
        body: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) => Column(
            children: [
              if (state.status == OrdersStatus.ready) const _Filters(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: context.read<OrdersCubit>().load,
                  child: _body(context, state, l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, OrdersState state, AppLocalizations l10n) {
    switch (state.status) {
      case OrdersStatus.loading:
        return PulseLoadingView(label: l10n.loadingLabel);
      case OrdersStatus.failure:
        return _scrollable(
          PulseMessageView(
            icon: Icons.error_outline,
            title: l10n.ordersLoadFailedTitle,
            body: resolver.resolve(state.error!, l10n),
            actionLabel: l10n.actionRetry,
            onAction: context.read<OrdersCubit>().load,
          ),
        );
      case OrdersStatus.ready:
        final orders = state.visible;
        if (orders.isEmpty) {
          final filtered =
              state.filter != OrderFilter.all || state.assetClass != null;
          return _scrollable(
            PulseMessageView(
              icon: filtered
                  ? Icons.filter_list_off
                  : Icons.receipt_long_outlined,
              title: filtered
                  ? l10n.ordersEmptyFilteredTitle
                  : l10n.ordersEmptyTitle,
              body: filtered
                  ? l10n.ordersEmptyFilteredBody
                  : l10n.ordersEmptyBody,
            ),
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PulseSpacing.md),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: PulseSpacing.sm),
          itemBuilder: (context, i) => _OrderCard(
            order: orders[i],
            instrument: state.instruments[orders[i].symbol],
            resolver: resolver,
          ),
        );
    }
  }

  Widget _scrollable(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}

/// Two dropdowns: order status (with counts) and stocks/crypto.
class _Filters extends StatelessWidget {
  const _Filters();

  static String statusLabel(AppLocalizations l10n, OrderFilter f) =>
      switch (f) {
        OrderFilter.all => l10n.orderFilterAll,
        OrderFilter.filled => l10n.orderFilterFilled,
        OrderFilter.pending => l10n.orderFilterPending,
        OrderFilter.working => l10n.orderFilterWorking,
        OrderFilter.rejected => l10n.orderFilterRejected,
        OrderFilter.cancelled => l10n.orderFilterCancelled,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OrdersCubit>();
    final state = context.watch<OrdersCubit>().state;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpacing.md,
        vertical: PulseSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<OrderFilter>(
              key: const ValueKey('status-filter'),
              initialValue: state.filter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.orderFilterStatusLabel,
                isDense: true,
              ),
              items: [
                for (final f in OrderFilter.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text('${statusLabel(l10n, f)} (${state.count(f)})'),
                  ),
              ],
              onChanged: (f) {
                if (f != null) cubit.setFilter(f);
              },
            ),
          ),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(
            child: DropdownButtonFormField<AssetClass?>(
              key: const ValueKey('asset-filter'),
              initialValue: state.assetClass,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.orderFilterAssetLabel,
                isDense: true,
              ),
              items: [
                DropdownMenuItem(child: Text(l10n.assetAll)),
                DropdownMenuItem(
                  value: AssetClass.stock,
                  child: Text(l10n.assetStock),
                ),
                DropdownMenuItem(
                  value: AssetClass.crypto,
                  child: Text(l10n.assetCrypto),
                ),
              ],
              onChanged: cubit.setAssetClass,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.instrument,
    required this.resolver,
  });

  final Order order;
  final Instrument? instrument;
  final ErrorMessageResolver resolver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final side = order.side == OrderSide.buy ? l10n.sideBuy : l10n.sideSell;
    final type = order.type == OrderType.market
        ? l10n.typeMarket
        : l10n.typeLimit;
    final unit = instrument == null
        ? ''
        : instrumentUnitLabel(instrument!.unit, l10n) ?? '';
    final currency = instrument?.currency ?? 'USD';
    final qty = DecimalFormatter.format(
      order.quantity,
      fractionDigits: instrument?.lotSize.scale ?? order.quantity.scale,
    );
    String price(Decimal v) =>
        '${DecimalFormatter.format(v, fractionDigits: instrument?.tickSize.scale ?? v.scale)} $currency';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PulseSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(order.symbol, style: theme.textTheme.titleMedium),
                ),
                const Spacer(),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: PulseSpacing.xs),
            Text(l10n.orderSideType(side, type)),
            Text(l10n.orderQuantityLine(qty, unit).trim()),
            if (order.limitPrice != null)
              Text(
                l10n.orderLimitPrice(price(order.limitPrice!)),
                style: theme.textTheme.bodySmall,
              ),
            if (order.status == OrderStatus.filled &&
                order.averagePrice != null)
              Text(
                l10n.orderFilledAt(price(order.averagePrice!)),
                style: theme.textTheme.bodySmall,
              ),
            if (order.status == OrderStatus.rejected)
              Padding(
                padding: const EdgeInsets.only(top: PulseSpacing.xs),
                child: Text(
                  _reason(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _reason(AppLocalizations l10n) {
    final code = order.rejectReason;
    if (code == null) return l10n.orderRejectedReasonUnknown;
    return resolver.resolve(BusinessRuleException(code: code), l10n);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      OrderStatus.filled => (
        l10n.orderStatusFilled,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      OrderStatus.pending => (
        l10n.orderStatusPending,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      OrderStatus.working => (
        l10n.orderStatusWorking,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      OrderStatus.rejected => (
        l10n.orderStatusRejected,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      OrderStatus.cancelled => (
        l10n.orderStatusCancelled,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      OrderStatus.unknown => (
        l10n.orderStatusUnknown,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}
