import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Tells the user how trustworthy the prices are, with an info sheet that
/// explains the real situation (ADR-0007). Hidden while prices are live.
class FeedStatusBanner extends StatelessWidget {
  const FeedStatusBanner({required this.hasSymbols, super.key});

  /// Without symbols there is nothing to connect to, so stay silent.
  final bool hasSymbols;

  @override
  Widget build(BuildContext context) {
    if (!hasSymbols) return const SizedBox.shrink();
    return BlocBuilder<PriceFeedCubit, PriceFeedState>(
      buildWhen: (a, b) =>
          a.status != b.status ||
          a.isReconnecting != b.isReconnecting ||
          a.lastMessageAt != b.lastMessageAt,
      builder: (context, state) {
        // A dropped socket is reported at once, not after the stale timer.
        final dropped = state.isReconnecting && state.quotes.isNotEmpty;
        if (state.status == FeedStatus.live && !dropped) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context);
        final (message, kind) = switch (dropped
            ? FeedStatus.offline
            : state.status) {
          FeedStatus.connecting => (l10n.feedConnecting, PulseBannerKind.info),
          FeedStatus.stale => (l10n.feedStale, PulseBannerKind.warning),
          FeedStatus.offline => (l10n.feedOffline, PulseBannerKind.error),
          FeedStatus.live => ('', PulseBannerKind.info),
        };
        final last = state.lastMessageAt;
        final text = last == null
            ? message
            : '$message\n${l10n.feedLastUpdate(_clock(last))}';
        return PulseStatusBanner(
          message: text,
          kind: kind,
          infoLabel: l10n.actionMoreInfo,
          onInfo: () => showPulseInfoSheet(
            context,
            title: l10n.feedInfoTitle,
            body: l10n.feedInfoBody,
            closeLabel: l10n.actionClose,
          ),
        );
      },
    );
  }

  /// HH:mm:ss with Latin digits (ADR-0009).
  static String _clock(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = time.toLocal();
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
