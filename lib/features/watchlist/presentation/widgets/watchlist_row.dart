import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/asset_style.dart';
import 'package:pulse/features/prices/domain/entities/price_change.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

class _RowPrice extends Equatable {
  const _RowPrice(this.quote, this.isStale);

  final PriceQuote? quote;
  final bool isStale;

  @override
  List<Object?> get props => [quote, isStale];
}

/// One watchlist row. It listens to ONE symbol of the shared feed, so a tick
/// of another symbol never rebuilds it (BLOC-07).
class WatchlistRow extends StatelessWidget {
  const WatchlistRow({
    required this.instrument,
    required this.onTap,
    this.trailing,
    this.selected = false,
    super.key,
  });

  final Instrument instrument;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Highlighted as the current selection in the two-pane layout.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PriceFeedCubit, PriceFeedState, _RowPrice>(
      selector: (state) => _RowPrice(
        state.quotes[instrument.symbol],
        state.status == FeedStatus.stale || state.status == FeedStatus.offline,
      ),
      builder: (context, price) => DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
        child: _RowBody(
          instrument: instrument,
          quote: price.quote,
          isStale: price.isStale,
          onTap: onTap,
          trailing: trailing,
        ),
      ),
    );
  }
}

class _RowBody extends StatelessWidget {
  const _RowBody({
    required this.instrument,
    required this.quote,
    required this.isStale,
    required this.onTap,
    required this.trailing,
  });

  final Instrument instrument;
  final PriceQuote? quote;
  final bool isStale;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final digits = instrument.tickSize.scale;
    final halted = !instrument.tradable;
    // A halted instrument has no live price: show the previous close.
    final shown = halted ? instrument.prevClose : quote?.last;
    final change = halted || shown == null
        ? null
        : PriceChange.compute(last: shown, prevClose: instrument.prevClose);
    final priceText = shown == null
        ? '—'
        : DecimalFormatter.format(shown, fractionDigits: digits);
    final dimmed = isStale && !halted;

    return Semantics(
      container: true,
      button: onTap != null,
      label: _semanticsLabel(l10n, priceText, change, digits, halted),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PulseSpacing.minTouchTarget + PulseSpacing.md,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: PulseSpacing.md,
              vertical: PulseSpacing.sm,
            ),
            child: Row(
              children: [
                PulseAssetAvatar(
                  size: 36,
                  symbol: instrument.symbol,
                  tone: assetTone(
                    assetClassOf(instrument.symbol, instrument),
                    theme,
                  ),
                ),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          instrument.symbol,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        instrument.name,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Opacity(
                      opacity: dimmed ? 0.55 : 1,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          priceText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (halted)
                      _Badge(
                        label: l10n.haltedBadge,
                        color: theme.extension<PulseSemanticColors>()?.halted,
                      )
                    else if (change != null)
                      PulsePriceChange(
                        direction: _direction(change.direction),
                        text: _changeText(change, digits),
                        semanticsLabel: '',
                        dimmed: dimmed,
                      ),
                    if (dimmed) _Badge(label: l10n.staleBadge),
                  ],
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel(
    AppLocalizations l10n,
    String priceText,
    PriceChange? change,
    int digits,
    bool halted,
  ) {
    if (halted) {
      return '${instrument.symbol}، ${l10n.haltedBadge}، $priceText';
    }
    if (change == null) return '${instrument.symbol}، $priceText';
    final direction = switch (change.direction) {
      PriceDirection.up => l10n.directionUp,
      PriceDirection.down => l10n.directionDown,
      PriceDirection.flat => l10n.directionFlat,
    };
    final base = l10n.rowSemantics(
      instrument.symbol,
      priceText,
      direction,
      _changeText(change, digits),
    );
    return isStale ? '$base، ${l10n.staleBadge}' : base;
  }

  static String _changeText(PriceChange change, int digits) {
    final absolute = DecimalFormatter.formatSigned(
      change.absolute,
      fractionDigits: digits,
    );
    final percent = DecimalFormatter.formatPercent(change.percent);
    return '$absolute ($percent)';
  }

  static PulseDirection _direction(PriceDirection d) => switch (d) {
    PriceDirection.up => PulseDirection.up,
    PriceDirection.down => PulseDirection.down,
    PriceDirection.flat => PulseDirection.flat,
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = color ?? theme.colorScheme.outline;
    return Container(
      margin: const EdgeInsetsDirectional.only(top: PulseSpacing.xs),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PulseSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone),
        borderRadius: BorderRadius.circular(PulseRadii.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
  }
}
