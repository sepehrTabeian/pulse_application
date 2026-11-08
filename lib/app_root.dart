import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/demo/domain/chaos_controller.dart';
import 'package:pulse/features/demo/presentation/chaos_switch.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/bloc/search_bloc.dart';
import 'package:pulse/features/instruments/presentation/pages/search_page.dart';
import 'package:pulse/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:pulse/features/orders/presentation/pages/orders_page.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';
import 'package:pulse/features/prices/presentation/cubit/price_feed_cubit.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/cubit/order_recovery_cubit.dart';
import 'package:pulse/features/trading/presentation/pages/ticket_page.dart';
import 'package:pulse/features/trading/presentation/widgets/ticket_pane_host.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:pulse/features/watchlist/presentation/pages/watchlist_page.dart';

/// Builds the app-wide blocs from the container, wires them together and
/// pauses the price connection while the app is in the background.
class AppRoot extends StatefulWidget {
  const AppRoot({required this.di, super.key});

  final GetIt di;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final PriceFeedCubit _feed = widget.di<PriceFeedCubit>();
  late final WatchlistCubit _watchlist = widget.di<WatchlistCubit>();
  late final PortfolioCubit _portfolio = widget.di<PortfolioCubit>();
  late final OrdersCubit _orders = widget.di<OrdersCubit>();
  late final OrderRecoveryCubit _recovery = widget.di<OrderRecoveryCubit>();
  late final ErrorMessageResolver _resolver = widget.di<ErrorMessageResolver>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchlist.load();
    _portfolio.load();
    _recovery.run();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _feed.resume();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _feed.pause();
      case AppLifecycleState.detached:
        // The app is going away: dispose the container, which closes the
        // fake server (every price socket and timer) with it.
        unawaited(widget.di.reset());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feed.close();
    _watchlist.close();
    _portfolio.close();
    _recovery.close();
    _orders.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PriceFeedCubit>.value(value: _feed),
        BlocProvider<WatchlistCubit>.value(value: _watchlist),
        BlocProvider<PortfolioCubit>.value(value: _portfolio),
        BlocProvider<OrderRecoveryCubit>.value(value: _recovery),
        BlocProvider<OrdersCubit>.value(value: _orders),
      ],
      child: MultiBlocListener(
        listeners: [
          // Watchlist symbols AND position symbols feed one connection.
          BlocListener<WatchlistCubit, WatchlistState>(
            listenWhen: (a, b) => a.symbols != b.symbols,
            listener: (_, state) => _feed.setWatchlistSymbols(state.symbols),
          ),
          BlocListener<PortfolioCubit, PortfolioState>(
            listenWhen: (a, b) => a.account != b.account,
            listener: (_, state) => _feed.setPositionSymbols([
              for (final p in state.account?.positions ?? const <Position>[])
                p.symbol,
            ]),
          ),
        ],
        child: PulseApp(
          home: _HomeShell(
            orders: _orders,
            onOpenSearch: _openSearch,
            watchlist: WatchlistPage(
              resolver: _resolver,
              onOpenTicket: _openTicket,
              onOpenSearch: _openSearch,
              initialTab: HomeTab.holdings,
              appBarActions: [
                if (widget.di.isRegistered<ChaosController>())
                  ChaosSwitch(controller: widget.di<ChaosController>()),
              ],
              ticketPaneBuilder: (context, instrument, onLockChanged) =>
                  TicketPaneHost(
                    instrument: instrument,
                    createOrderFlow: () => widget.di<OrderFlowBloc>(),
                    createCandles: (symbol) =>
                        widget.di<CandlesCubit>(param1: symbol),
                    resolver: _resolver,
                    onLockChanged: onLockChanged,
                  ),
            ),
            ordersPage: OrdersPage(resolver: _resolver),
          ),
        ),
      ),
    );
  }

  void _openTicket(BuildContext context, Instrument instrument) {
    final orderFlow = widget.di<OrderFlowBloc>();
    final candles = widget.di<CandlesCubit>(param1: instrument.symbol)..load();
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider<PriceFeedCubit>.value(value: _feed),
                BlocProvider<PortfolioCubit>.value(value: _portfolio),
              ],
              child: TicketPage(
                instrument: instrument,
                orderFlow: orderFlow,
                candles: candles,
                resolver: _resolver,
              ),
            ),
          ),
        )
        .whenComplete(() {
          orderFlow.close();
          candles.close();
        });
  }

  void _openSearch(BuildContext context) {
    final search = widget.di<SearchBloc>();
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<WatchlistCubit>.value(
              value: _watchlist,
              child: SearchPage(searchBloc: search, resolver: _resolver),
            ),
          ),
        )
        .whenComplete(search.close);
  }
}

/// Bottom navigation: watchlist, orders and a shortcut to search/add.
/// Search opens as its own screen, so the selected tab never moves to it.
class _HomeShell extends StatefulWidget {
  const _HomeShell({
    required this.watchlist,
    required this.ordersPage,
    required this.orders,
    required this.onOpenSearch,
  });

  final Widget watchlist;
  final Widget ordersPage;
  final OrdersCubit orders;
  final void Function(BuildContext context) onOpenSearch;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  static const int _watchlistTab = 0;
  static const int _ordersTab = 1;
  static const int _searchTab = 2;

  int _index = _watchlistTab;

  void _select(int index) {
    if (index == _searchTab) {
      widget.onOpenSearch(context);
      return;
    }
    if (index == _ordersTab) unawaited(widget.orders.load());
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [widget.watchlist, widget.ordersPage],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.show_chart),
            label: l10n.navWatchlist,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: l10n.navSearchAdd,
          ),
        ],
      ),
    );
  }
}
