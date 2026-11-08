import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/format/decimal_formatter.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Price chart with a range selector (Could #9). Selecting a bar shows its
/// exact OHLC values; exact numbers stay `Decimal` and are only converted to
/// pixels inside the chart.
class CandleSection extends StatefulWidget {
  const CandleSection({
    required this.instrument,
    required this.resolver,
    this.chartHeight = 200,
    super.key,
  });

  final Instrument instrument;
  final ErrorMessageResolver resolver;
  final double chartHeight;

  @override
  State<CandleSection> createState() => _CandleSectionState();
}

class _CandleSectionState extends State<CandleSection> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<CandlesCubit, CandlesState>(
      listenWhen: (a, b) => a.candles != b.candles,
      listener: (_, _) => setState(() => _selected = null),
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chartTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<CandleRange>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: CandleRange.day,
                      label: Text(l10n.rangeDay),
                    ),
                    ButtonSegment(
                      value: CandleRange.week,
                      label: Text(l10n.rangeWeek),
                    ),
                    ButtonSegment(
                      value: CandleRange.month,
                      label: Text(l10n.rangeMonth),
                    ),
                  ],
                  selected: {state.range},
                  onSelectionChanged: (s) =>
                      context.read<CandlesCubit>().setRange(s.first),
                ),
              ],
            ),
            const SizedBox(height: PulseSpacing.sm),
            SizedBox(
              height: widget.chartHeight,
              child: _body(context, state, l10n),
            ),
            if (state.status == CandlesStatus.ready) ...[
              const SizedBox(height: PulseSpacing.xs),
              _selectedInfo(state, l10n, theme),
              Text(l10n.chartLegend, style: theme.textTheme.bodySmall),
            ],
          ],
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    CandlesState state,
    AppLocalizations l10n,
  ) {
    return switch (state.status) {
      CandlesStatus.loading => PulseLoadingView(label: l10n.loadingLabel),
      CandlesStatus.empty => PulseMessageView(
        icon: Icons.show_chart,
        title: l10n.chartEmpty,
      ),
      CandlesStatus.failure => PulseMessageView(
        icon: Icons.error_outline,
        title: widget.resolver.resolve(state.error!, l10n),
        actionLabel: l10n.actionRetry,
        onAction: () => context.read<CandlesCubit>().load(),
      ),
      CandlesStatus.ready => PulseCandleChart(
        height: widget.chartHeight,
        selectedIndex: _selected,
        onSelected: (i) => setState(() => _selected = i),
        semanticsLabel: _summary(state.candles, l10n),
        bars: [
          for (final c in state.candles)
            PulseCandleBar(
              open: c.open.toDouble(),
              high: c.high.toDouble(),
              low: c.low.toDouble(),
              close: c.close.toDouble(),
            ),
        ],
      ),
    };
  }

  String _summary(List<Candle> candles, AppLocalizations l10n) {
    var low = candles.first.low;
    var high = candles.first.high;
    for (final c in candles) {
      if (c.low < low) low = c.low;
      if (c.high > high) high = c.high;
    }
    return l10n.chartSummary(
      widget.instrument.symbol,
      candles.length.toString(),
      _price(low),
      _price(high),
    );
  }

  Widget _selectedInfo(
    CandlesState state,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final index = _selected;
    if (index == null || index >= state.candles.length) {
      return const SizedBox.shrink();
    }
    final c = state.candles[index];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        l10n.chartSelected(
          _time(c.time, state.range),
          _price(c.open),
          _price(c.high),
          _price(c.low),
          _price(c.close),
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  String _price(Decimal value) => DecimalFormatter.format(
    value,
    fractionDigits: widget.instrument.tickSize.scale,
  );

  /// Latin digits (ADR-0009).
  static String _time(DateTime utc, CandleRange range) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = utc.toLocal();
    return switch (range) {
      CandleRange.day => '${two(t.hour)}:${two(t.minute)}',
      CandleRange.week => '${two(t.month)}/${two(t.day)} ${two(t.hour)}:00',
      CandleRange.month => '${two(t.month)}/${two(t.day)}',
    };
  }
}
