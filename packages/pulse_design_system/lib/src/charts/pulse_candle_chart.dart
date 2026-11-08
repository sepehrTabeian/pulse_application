import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulse_design_system/src/tokens/pulse_semantic_colors.dart';

/// One bar to draw. Plain numbers because this is PIXEL math only; exact
/// money values stay `Decimal` in the app and are converted at the edge.
class PulseCandleBar {
  const PulseCandleBar({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;

  bool get isUp => close >= open;
}

/// Pure layout math, separated from painting so it can be unit-tested.
class CandleChartGeometry {
  CandleChartGeometry({
    required this.bars,
    required this.size,
    this.padding = 8,
  }) {
    if (bars.isEmpty) {
      minValue = 0;
      maxValue = 1;
      return;
    }
    var low = bars.first.low;
    var high = bars.first.high;
    for (final bar in bars) {
      low = math.min(low, math.min(bar.low, math.min(bar.open, bar.close)));
      high = math.max(high, math.max(bar.high, math.max(bar.open, bar.close)));
    }
    if (high == low) {
      // A flat market still needs a drawable range.
      final margin = high == 0 ? 1.0 : high.abs() * 0.01;
      low -= margin;
      high += margin;
    }
    minValue = low;
    maxValue = high;
  }

  final List<PulseCandleBar> bars;
  final Size size;
  final double padding;
  late final double minValue;
  late final double maxValue;

  double get slotWidth => bars.isEmpty ? 0 : size.width / bars.length;

  double get bodyWidth => math.max(1, slotWidth * 0.6);

  double centerX(int index) => slotWidth * (index + 0.5);

  /// Higher values are nearer the top.
  double yFor(double value) {
    final usable = math.max(1, size.height - 2 * padding);
    final ratio = (value - minValue) / (maxValue - minValue);
    return padding + (1 - ratio) * usable;
  }

  /// Bar under a horizontal touch position, or null when there is none.
  int? indexAt(double dx) {
    if (bars.isEmpty || size.width <= 0) return null;
    final clamped = dx.clamp(0, size.width - 0.001);
    return (clamped / slotWidth).floor().clamp(0, bars.length - 1);
  }
}

/// Candlestick chart. Direction is NOT colour-only: rising bars are HOLLOW
/// outlines, falling bars are FILLED (DS-05). Tap or drag selects a bar.
class PulseCandleChart extends StatelessWidget {
  const PulseCandleChart({
    required this.bars,
    required this.semanticsLabel,
    this.selectedIndex,
    this.onSelected,
    this.height = 200,
    super.key,
  });

  final List<PulseCandleBar> bars;
  final String semanticsLabel;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<PulseSemanticColors>() ??
        PulseSemanticColors.light;
    final grid = Theme.of(context).colorScheme.outlineVariant;
    final highlight = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, height);
            void select(double dx) {
              final index = CandleChartGeometry(
                bars: bars,
                size: size,
              ).indexAt(dx);
              if (index != null) onSelected?.call(index);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => select(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => select(d.localPosition.dx),
              child: CustomPaint(
                size: size,
                painter: _CandlePainter(
                  bars: bars,
                  upColor: colors.priceUp,
                  downColor: colors.priceDown,
                  gridColor: grid,
                  highlightColor: highlight,
                  selectedIndex: selectedIndex,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.bars,
    required this.upColor,
    required this.downColor,
    required this.gridColor,
    required this.highlightColor,
    required this.selectedIndex,
  });

  final List<PulseCandleBar> bars;
  final Color upColor;
  final Color downColor;
  final Color gridColor;
  final Color highlightColor;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = CandleChartGeometry(bars: bars, size: size);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = geometry.padding + (size.height - 2 * geometry.padding) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (bars.isEmpty) return;

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < bars.length) {
      final x = geometry.centerX(selected);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = highlightColor
          ..strokeWidth = 1.5,
      );
    }

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final color = bar.isUp ? upColor : downColor;
      final x = geometry.centerX(i);
      final wick = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x, geometry.yFor(bar.high)),
        Offset(x, geometry.yFor(bar.low)),
        wick,
      );
      final top = geometry.yFor(math.max(bar.open, bar.close));
      final bottom = geometry.yFor(math.min(bar.open, bar.close));
      final rect = Rect.fromLTRB(
        x - geometry.bodyWidth / 2,
        top,
        x + geometry.bodyWidth / 2,
        math.max(bottom, top + 1),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = bar.isUp ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.bars != bars ||
      old.selectedIndex != selectedIndex ||
      old.upColor != upColor ||
      old.downColor != downColor;
}
