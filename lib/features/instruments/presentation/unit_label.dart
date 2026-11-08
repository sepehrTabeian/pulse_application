import 'package:pulse/core/l10n/generated/app_localizations.dart';

/// Display text for an instrument unit; null when there is none.
String? instrumentUnitLabel(String unit, AppLocalizations l10n) {
  if (unit.isEmpty) return null;
  return unit == 'share' ? l10n.unitShare : unit;
}
