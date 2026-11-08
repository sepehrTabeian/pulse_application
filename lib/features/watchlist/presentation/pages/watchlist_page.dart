import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/adaptive_layout.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/portfolio/presentation/widgets/holding_row.dart';
import 'package:pulse/features/portfolio/presentation/widgets/portfolio_header.dart';
import 'package:pulse/features/prices/presentation/widgets/feed_status_banner.dart';
import 'package:pulse/features/trading/domain/use_cases/reconcile_pending_orders.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:pulse/features/watchlist/presentation/widgets/watchlist_row.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Opens the ticket / search screens. Supplied by the composition root so
/// this page never builds blocs itself.
typedef InstrumentOpener = void Function(BuildContext context, Instrument item);

/// The two lists of the home page: what the user owns and what they follow.
enum HomeTab { holdings, watchlist }

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({
    required this.resolver,
    required this.onOpenTicket,
    required this.onOpenSearch,
    this.ticketPaneBuilder,
    this.initialTab = HomeTab.watchlist,
    this.appBarActions = const <Widget>[],
    super.key,
  });

  final ErrorMessageResolver resolver;
  final InstrumentOpener onOpenTicket;
  final HomeTab initialTab;

  /// Extra app-bar controls (the demo chaos switch).
  final List<Widget> appBarActions;
  final void Function(BuildContext context) onOpenSearch;

  /// Builds the tablet detail pane. `onLockChanged(true)` is reported while an
  /// order is in flight so the list refuses to switch symbols. When null the
  /// page is always single-pane.
  final Widget Function(
    BuildContext context,
    Instrument instrument,
    ValueChanged<bool> onLockChanged,
  )?
  ticketPaneBuilder;

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  late HomeTab _tab = widget.initialTab;
  AssetClass? _asset;
  Instrument? _selected;
  bool _locked = false;

  Future<void> _refresh() async {
    await Future.wait([
      context.read<WatchlistCubit>().load(),
      context.read<PortfolioCubit>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<WatchlistCubit, WatchlistState>(
      listenWhen: (a, b) => b.saveError != null && a.saveError != b.saveError,
      listener: _showSaveError,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.homeTitle),
          actions: widget.appBarActions,
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final twoPane =
        widget.ticketPaneBuilder != null && AdaptiveLayout.isTwoPaneOf(context);
    final selected = _selected;
    final list = _listColumn(context, twoPane: twoPane);
    if (twoPane) {
      return Row(
        children: [
          SizedBox(width: AdaptiveLayout.listPaneWidth, child: list),
          const VerticalDivider(width: 1),
          Expanded(child: _detail(context, selected)),
        ],
      );
    }
    // The window became narrow while an order is in flight: keep the live
    // order flow on screen instead of destroying it.
    if (_locked && selected != null) return _detail(context, selected);
    return list;
  }

  Widget _detail(BuildContext context, Instrument? selected) {
    final l10n = AppLocalizations.of(context);
    if (selected == null || widget.ticketPaneBuilder == null) {
      return PulseMessageView(
        icon: Icons.touch_app_outlined,
        title: l10n.selectInstrumentTitle,
        body: l10n.selectInstrumentBody,
      );
    }
    return KeyedSubtree(
      key: GlobalObjectKey(selected.symbol),
      child: widget.ticketPaneBuilder!(
        context,
        selected,
        (locked) => setState(() => _locked = locked),
      ),
    );
  }

  Widget _listColumn(BuildContext context, {required bool twoPane}) {
    return Column(
      children: [
        BlocBuilder<WatchlistCubit, WatchlistState>(
          buildWhen: (a, b) => a.symbols.isEmpty != b.symbols.isEmpty,
          builder: (context, state) =>
              FeedStatusBanner(hasSymbols: state.symbols.isNotEmpty),
        ),
        _RecoveryNotices(),
        Expanded(
          child: BlocBuilder<WatchlistCubit, WatchlistState>(
            builder: (context, state) => RefreshIndicator(
              onRefresh: _refresh,
              child: _content(context, state, twoPane: twoPane),
            ),
          ),
        ),
      ],
    );
  }

  void _onRowTap(BuildContext context, Instrument instrument, bool twoPane) {
    if (!twoPane) {
      widget.onOpenTicket(context, instrument);
      return;
    }
    if (_locked && _selected?.symbol != instrument.symbol) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).switchBlocked)),
        );
      return;
    }
    setState(() => _selected = instrument);
  }

  Widget _content(
    BuildContext context,
    WatchlistState state, {
    required bool twoPane,
  }) {
    final l10n = AppLocalizations.of(context);
    return switch (state.status) {
      WatchlistStatus.loading => PulseLoadingView(label: l10n.loadingLabel),
      WatchlistStatus.failure => _scrollable(
        PulseMessageView(
          icon: Icons.error_outline,
          title: l10n.watchlistLoadFailedTitle,
          body: widget.resolver.resolve(state.error!, l10n),
          actionLabel: l10n.actionRetry,
          onAction: _refresh,
        ),
      ),
      WatchlistStatus.ready when _tab == HomeTab.holdings => _holdings(
        context,
        state,
        twoPane: twoPane,
      ),
      WatchlistStatus.ready when state.isEmpty => _scrollable(
        Column(
          children: [
            _header(context, state),
            PulseMessageView(
              icon: Icons.inbox_outlined,
              title: l10n.watchlistEmptyTitle,
              body: l10n.watchlistEmptyBody,
              actionLabel: l10n.actionAdd,
              onAction: () => widget.onOpenSearch(context),
            ),
          ],
        ),
      ),
      WatchlistStatus.ready => _list(context, state, twoPane: twoPane),
    };
  }

  /// Balance, the holdings/watchlist switch and the stocks/crypto switch.
  Widget _header(BuildContext context, WatchlistState state, {_Hint? hint}) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        PortfolioHeader(instruments: state.instruments),
        _HomeTabs(
          selected: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        _AssetFilter(
          selected: _asset,
          onChanged: (value) => setState(() => _asset = value),
        ),
        if (hint != null)
          _HintBanner(
            icon: hint.icon,
            text: hint == _Hint.holdings
                ? l10n.holdingsHint
                : l10n.watchlistHint,
            holdings: hint == _Hint.holdings,
          ),
      ],
    );
  }

  /// What the user owns, from the server's account: every row shows its
  /// value and amount. Deliberately different from the watchlist rows.
  Widget _holdings(
    BuildContext context,
    WatchlistState state, {
    required bool twoPane,
  }) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<PortfolioCubit, PortfolioState>(
      builder: (context, portfolio) {
        final account = portfolio.account;
        final owned = [
          for (final p in account?.positions ?? const <Position>[])
            if (p.quantity > Decimal.zero) p,
        ];
        final shown = [
          for (final p in owned)
            if (_asset == null ||
                assetClassOf(p.symbol, state.instruments[p.symbol]) == _asset)
              p,
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(context, state, hint: _Hint.holdings),
            if (account != null && owned.isEmpty)
              SizedBox(
                height: 320,
                child: PulseMessageView(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.holdingsEmptyTitle,
                  body: l10n.holdingsEmptyBody,
                  actionLabel: l10n.holdingsEmptyAction,
                  onAction: () => setState(() => _tab = HomeTab.watchlist),
                ),
              )
            else if (account != null && shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(PulseSpacing.lg),
                child: Center(child: Text(l10n.holdingsAssetEmpty)),
              )
            else
              for (final p in shown) ...[
                HoldingRow(
                  position: p,
                  instrument: state.instruments[p.symbol],
                  currency: account!.currency,
                  onTap: state.instruments[p.symbol] == null
                      ? null
                      : () => _onRowTap(
                          context,
                          state.instruments[p.symbol]!,
                          twoPane,
                        ),
                ),
                const Divider(height: 1),
              ],
          ],
        );
      },
    );
  }

  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WatchlistState state, {
    required bool twoPane,
  }) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WatchlistCubit>();
    final all = state.items;
    final items = _asset == null
        ? all
        : [
            for (final item in all)
              if (assetClassOf(item.symbol, item.instrument) == _asset) item,
          ];
    // Reordering is only meaningful on the full list.
    final canReorder = _asset == null;
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      header: _header(context, state, hint: _Hint.watchlist),
      footer: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(PulseSpacing.lg),
              child: Center(child: Text(l10n.watchlistAssetEmpty)),
            )
          : null,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: cubit.reorder,
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.symbol),
          direction: DismissDirection.horizontal,
          background: const _DeleteBackground(),
          // The cubit removes the row at once (and rolls back on a failed
          // save), so the Dismissible itself never stays in a dismissed state.
          confirmDismiss: (_) async {
            unawaited(cubit.remove(item.symbol));
            return false;
          },
          child: WatchlistRow(
            instrument: item.instrument,
            selected: twoPane && _selected?.symbol == item.symbol,
            onTap: () => _onRowTap(context, item.instrument, twoPane),
            trailing: canReorder
                ? ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: l10n.watchlistReorderHandle(item.symbol),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: PulseSpacing.sm,
                        ),
                        child: Icon(Icons.drag_indicator, size: 20),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showSaveError(BuildContext context, WatchlistState state) {
    final error = state.saveError;
    if (error == null) return;
    final l10n = AppLocalizations.of(context);
    var message = widget.resolver.resolve(error, l10n);
    // A local rejection never touched the list; a failed save did roll back.
    if (error is! ValidationException) {
      message = '$message\n${l10n.watchlistSaveRolledBack}';
    }
    final cubit = context.read<WatchlistCubit>();
    final canRetry = cubit.canRetrySave;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: canRetry
              ? SnackBarAction(
                  label: l10n.actionRetry,
                  onPressed: cubit.retryFailedSave,
                )
              : null,
        ),
      );
    cubit.clearSaveError();
  }
}

/// What the server told us about orders unconfirmed at the last app close.
class _RecoveryNotices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OrderRecoveryCubit, List<RecoveryResult>>(
      builder: (context, results) {
        if (results.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final result in results)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: PulseSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_message(l10n, result))),
                      TextButton(
                        onPressed: () =>
                            context.read<OrderRecoveryCubit>().dismiss(result),
                        child: Text(l10n.actionDismiss),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _message(AppLocalizations l10n, RecoveryResult result) {
    final symbol = result.pending.request.symbol;
    return switch (result) {
      OrderRecovered(:final order) when order.status.name == 'working' =>
        l10n.recoveryWorking(symbol),
      OrderRecovered() => l10n.recoveryFilled(symbol),
      OrderNotExecuted() => l10n.recoveryNotExecuted(symbol),
      OrderStillUnresolved() ||
      OrderCheckFailed() => l10n.recoveryStillUnresolved(symbol),
    };
  }
}

/// Red swipe background shown while a row is dragged away to delete it.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ],
        ),
      ),
    );
  }
}

/// All / stocks / crypto switch above the watchlist.
class _AssetFilter extends StatelessWidget {
  const _AssetFilter({required this.selected, required this.onChanged});

  final AssetClass? selected;
  final ValueChanged<AssetClass?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PulseSpacing.md,
        0,
        PulseSpacing.md,
        PulseSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<AssetClass?>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          segments: [
            ButtonSegment(value: null, label: Text(l10n.assetAll)),
            ButtonSegment(
              value: AssetClass.stock,
              label: Text(l10n.assetStock),
            ),
            ButtonSegment(
              value: AssetClass.crypto,
              label: Text(l10n.assetCrypto),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

enum _Hint {
  holdings(Icons.account_balance_wallet_outlined),
  watchlist(Icons.visibility_outlined);

  const _Hint(this.icon);

  final IconData icon;
}

/// Home tabs: owned assets vs followed symbols.
class _HomeTabs extends StatelessWidget {
  const _HomeTabs({required this.selected, required this.onChanged});

  final HomeTab selected;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PulseSpacing.md,
        0,
        PulseSpacing.md,
        PulseSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<HomeTab>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.comfortable,
          ),
          segments: [
            ButtonSegment(
              value: HomeTab.holdings,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(l10n.homeTabHoldings),
            ),
            ButtonSegment(
              value: HomeTab.watchlist,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.homeTabWatchlist),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

/// One line under the switches saying what the list below is.
class _HintBanner extends StatelessWidget {
  const _HintBanner({
    required this.icon,
    required this.text,
    required this.holdings,
  });

  final IconData icon;
  final String text;
  final bool holdings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = holdings ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = holdings ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        PulseSpacing.md,
        0,
        PulseSpacing.md,
        PulseSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpacing.md,
        vertical: PulseSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
