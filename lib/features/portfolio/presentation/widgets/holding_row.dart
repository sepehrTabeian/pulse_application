import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/asset_style.dart';
import 'package:pulse/features/instruments/presentation/unit_label.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/services/portfolio_valuation.dart';
import 'package:pulse/features/prices/domain/entities/price_change.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// One owned asset (Trust-Wallet style): name and live price on the left,
/// what it is worth now and how much is owned on the right. It listens to
/// ONE symbol of the shared feed.
class HoldingRow extends StatelessWidget {
  const HoldingRow({
    required this.position,
    required this.instrument,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final Position position;
  final Instrument? instrument;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PriceFeedCubit, PriceFeedState, PriceQuote?>(
      selector: (state) => state.quotes[position.symbol],
      builder: (context, quote) => _Body(
        position: position,
        instrument: instrument,
        currency: currency,
        quote: quote,
        onTap: onTap,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.position,
    required this.instrument,
    required this.currency,
    required this.quote,
    required this.onTap,
  });

  final Position position;
  final Instrument? instrument;
  final String currency;
  final PriceQuote? quote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.extension<PulseSemanticColors>();
    final inst = instrument;
    final value = PortfolioValuation.compute(
      account: Account(
        currency: currency,
        cash: Decimal.zero,
        positions: [position],
      ),
      quotes: {position.symbol: ?quote},
      instruments: {position.symbol: ?inst},
    ).positions.single;
    final assetClass = assetClassOf(position.symbol, inst);
    final tickDigits = inst?.tickSize.scale ?? 2;
    final price = quote?.last ?? inst?.prevClose;
    final change = price == null || inst?.prevClose == null
        ? null
        : PriceChange.compute(last: price, prevClose: inst!.prevClose);
    final unit = inst == null ? '' : instrumentUnitLabel(inst.unit, l10n) ?? '';
    final qty = DecimalFormatter.format(
      position.quantity,
      fractionDigits: position.quantity.scale,
    );
    final changeColor = switch (change?.direction) {
      PriceDirection.up => colors?.priceUp,
      PriceDirection.down => colors?.priceDown,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: PulseSpacing.md,
          vertical: PulseSpacing.sm + 2,
        ),
        child: Row(
          children: [
            PulseAssetAvatar(
              symbol: position.symbol,
              tone: assetTone(assetClass, theme),
            ),
            const SizedBox(width: PulseSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inst?.name ?? position.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      price == null
                          ? position.symbol
                          : '${DecimalFormatter.format(price, fractionDigits: tickDigits)}'
                                '${change == null ? '' : '  ${DecimalFormatter.formatPercent(change.percent)}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    value.hasPrice
                        ? '${DecimalFormatter.format(value.valueAtLast)} $currency'
                        : '—',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$qty $unit'.trim(), style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
