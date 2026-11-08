import 'package:flutter/material.dart';
import 'package:pulse_design_system/src/tokens/pulse_spacing.dart';

/// Main call-to-action. While [isPending] it is disabled and shows progress,
/// so it can never fire twice (ORD-01). Disabled too when [onPressed] is null.
class PulsePrimaryButton extends StatelessWidget {
  const PulsePrimaryButton({
    required this.label,
    required this.onPressed,
    this.isPending = false,
    this.pendingLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPending;

  /// Text shown next to the progress indicator while pending.
  final String? pendingLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isPending;
    return SizedBox(
      width: double.infinity,
      height: PulseSpacing.minTouchTarget,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: isPending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  if (pendingLabel != null) ...[
                    const SizedBox(width: PulseSpacing.sm),
                    Flexible(child: Text(pendingLabel!)),
                  ],
                ],
              )
            : Text(label),
      ),
    );
  }
}
