import 'package:flutter/material.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Accent colour of an asset class: the crypto token for coins, the theme
/// colour for stocks. Used by the avatar so the two kinds are told apart at
/// a glance.
Color assetTone(AssetClass assetClass, ThemeData theme) => switch (assetClass) {
  AssetClass.crypto =>
    theme.extension<PulseSemanticColors>()?.crypto ??
        theme.colorScheme.tertiary,
  AssetClass.stock => theme.colorScheme.primary,
};
