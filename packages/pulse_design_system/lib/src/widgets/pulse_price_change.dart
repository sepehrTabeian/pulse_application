import 'package:flutter/material.dart';
import 'package:pulse_design_system/src/tokens/pulse_semantic_colors.dart';
import 'package:pulse_design_system/src/tokens/pulse_spacing.dart';

enum PulseDirection { up, down, flat }

/// Shows a price change so that direction is NEVER conveyed by colour alone
/// (DS-05): an arrow icon, an explicit sign inside [text], and a semantics
/// label are always present.
class PulsePriceChange extends StatelessWidget {
  const PulsePriceChange({
    required this.direction,
    required this.text,
    required this.semanticsLabel,
    this.dimmed = false,
    super.key,
  });

  final PulseDirection direction;

  /// Already formatted and signed, e.g. "+1.50 (+0.66%)". Always LTR.
  final String text;

  /// Full spoken description including the direction word.
  final String semanticsLabel;

  /// True when the price is stale: de-emphasised.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<PulseSemanticColors>() ??
        PulseSemanticColors.light;
    final color = switch (direction) {
      PulseDirection.up => colors.priceUp,
      PulseDirection.down => colors.priceDown,
      PulseDirection.flat => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final icon = switch (direction) {
      PulseDirection.up => Icons.arrow_upward,
      PulseDirection.down => Icons.arrow_downward,
      PulseDirection.flat => Icons.remove,
    };
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: PulseSpacing.xs),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
