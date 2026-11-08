import 'package:flutter/material.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Root widget. Persian (RTL) now; English is added via ARB later (ADR-0002).
class PulseApp extends StatelessWidget {
  const PulseApp({required this.home, super.key});

  final Widget home;

  static const Locale _locale = Locale('fa');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: PulseTheme.light(),
      darkTheme: PulseTheme.dark(),
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
  }
}
