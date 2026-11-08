import 'package:flutter/material.dart';
import 'package:pulse_design_system/src/tokens/pulse_semantic_colors.dart';
import 'package:pulse_design_system/src/tokens/pulse_spacing.dart';

enum PulseBannerKind { info, warning, error }

/// Full-width status strip with an optional info action (ADR-0007).
/// All text is supplied by the caller (already localized).
class PulseStatusBanner extends StatelessWidget {
  const PulseStatusBanner({
    required this.message,
    required this.kind,
    this.infoLabel,
    this.onInfo,
    super.key,
  });

  final String message;
  final PulseBannerKind kind;

  /// Accessible label of the info button; required when [onInfo] is set.
  final String? infoLabel;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<PulseSemanticColors>() ??
        PulseSemanticColors.light;
    final (background, foreground, icon) = switch (kind) {
      PulseBannerKind.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
      PulseBannerKind.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.schedule,
      ),
      PulseBannerKind.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.cloud_off,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: background,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: PulseSpacing.md,
            vertical: PulseSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: PulseSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
              if (onInfo != null)
                IconButton(
                  onPressed: onInfo,
                  tooltip: infoLabel,
                  icon: Icon(
                    Icons.help_outline,
                    color: kind == PulseBannerKind.warning
                        ? semantic.halted
                        : foreground,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: PulseSpacing.minTouchTarget,
                    minHeight: PulseSpacing.minTouchTarget,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
