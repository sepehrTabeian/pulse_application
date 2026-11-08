import 'package:flutter/material.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/demo/domain/chaos_controller.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Demo control: flips the fake server between its realistic and storm
/// profiles while the app runs. The price banner, reconnects and
/// retries then react by themselves (the app never learns about the switch).
class ChaosSwitch extends StatefulWidget {
  const ChaosSwitch({required this.controller, super.key});

  final ChaosController controller;

  @override
  State<ChaosSwitch> createState() => _ChaosSwitchState();
}

class _ChaosSwitchState extends State<ChaosSwitch> {
  bool get _isStorm => widget.controller.isStorm;

  void _toggle(bool storm) {
    widget.controller.setStorm(enabled: storm);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.chaosSwitchTooltip,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: PulseSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              size: 18,
              color: _isStorm ? scheme.error : scheme.onSurfaceVariant,
            ),
            Switch(
              key: const ValueKey('chaos-switch'),
              value: _isStorm,
              onChanged: _toggle,
            ),
          ],
        ),
      ),
    );
  }
}
