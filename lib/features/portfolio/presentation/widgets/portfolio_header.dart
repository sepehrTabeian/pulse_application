import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/domain/services/portfolio_valuation.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Cash plus live market value of positions (Should #8, ADR-0008). Shows an
/// approximate value by `last` and a "sell now" value by `bid`; the info
/// sheet explains how they are computed.
class PortfolioHeader extends StatelessWidget {
  const PortfolioHeader({required this.instruments, super.key});

  /// Whole catalogue, used for the previous-close fallback.
  final Map<String, Instrument> instruments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<PortfolioCubit, PortfolioState>(
      builder: (context, portfolio) {
        final account = portfolio.account;
        if (account == null) {
          return switch (portfolio.status) {
            PortfolioStatus.failure => _Notice(text: l10n.portfolioLoadFailed),
            _ => const LinearProgressIndicator(),
          };
        }
        return BlocBuilder<PriceFeedCubit, PriceFeedState>(
          buildWhen: (a, b) =>
              !identical(a.quotes, b.quotes) || a.status != b.status,
          builder: (context, feed) {
            final valuation = PortfolioValuation.compute(
              account: account,
              quotes: feed.quotes,
              instruments: instruments,
            );
            return _Content(
              valuation: valuation,
              currency: account.currency,
              isStale:
                  feed.status == FeedStatus.stale ||
                  feed.status == FeedStatus.offline,
            );
          },
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.valuation,
    required this.currency,
    required this.isStale,
  });

  final PortfolioValuation valuation;
  final String currency;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String money(Decimal value) =>
        '${DecimalFormatter.format(value)} $currency';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PulseSpacing.md,
        PulseSpacing.sm,
        PulseSpacing.md,
        PulseSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  l10n.portfolioTotal,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.actionMoreInfo,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showPulseInfoSheet(
                  context,
                  title: l10n.portfolioInfoTitle,
                  body: l10n.portfolioInfoBody,
                  closeLabel: l10n.actionClose,
                ),
              ),
            ],
          ),
          Opacity(
            opacity: isStale ? 0.55 : 1,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(valuation.totalAtLast),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PulseSpacing.md),
          Row(
            children: [
              _Stat(
                label: l10n.portfolioCash,
                value: money(valuation.cash),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(width: PulseSpacing.sm),
              _Stat(
                label: l10n.portfolioMarketValue,
                value: money(valuation.marketValueLast),
                icon: Icons.pie_chart_outline,
                dimmed: isStale,
              ),
              const SizedBox(width: PulseSpacing.sm),
              _Stat(
                label: l10n.portfolioSellNow,
                value: money(valuation.sellNowValue),
                icon: Icons.sell_outlined,
                dimmed: isStale,
              ),
            ],
          ),
          if (valuation.hasApproximation)
            Padding(
              padding: const EdgeInsets.only(top: PulseSpacing.sm),
              child: Text(
                l10n.portfolioApproximate,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (valuation.hasMissingPrice)
            Text(l10n.portfolioMissingPrice, style: theme.textTheme.bodySmall),
          if (isStale) Text(l10n.staleBadge, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One of the three small figures under the balance.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.dimmed = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PulseSpacing.sm,
            vertical: PulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PulseSpacing.md),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
