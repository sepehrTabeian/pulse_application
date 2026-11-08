import 'package:flutter/material.dart';
import 'package:pulse_design_system/src/tokens/pulse_spacing.dart';

/// Bottom sheet that explains a status to the user in plain words
/// (ADR-0007, ADR-0008). Text is supplied by the caller.
Future<void> showPulseInfoSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String closeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PulseSpacing.lg,
          0,
          PulseSpacing.lg,
          PulseSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: PulseSpacing.sm),
            Text(body, style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: PulseSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(closeLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
