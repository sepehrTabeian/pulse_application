import 'package:flutter/material.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/candles/presentation/cubit/candles_cubit.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/trading/presentation/bloc/order_flow_bloc.dart';
import 'package:pulse/features/trading/presentation/pages/ticket_page.dart';

/// Owns the blocs of the tablet detail pane for ONE instrument and closes
/// them on dispose. The list gives it a `ValueKey(symbol)` so a new symbol
/// gets fresh state; switching is refused while an order is in flight, so a
/// live order flow can never be disposed.
class TicketPaneHost extends StatefulWidget {
  const TicketPaneHost({
    required this.instrument,
    required this.createOrderFlow,
    required this.createCandles,
    required this.resolver,
    required this.onLockChanged,
    super.key,
  });

  final Instrument instrument;
  final OrderFlowBloc Function() createOrderFlow;
  final CandlesCubit Function(String symbol) createCandles;
  final ErrorMessageResolver resolver;
  final ValueChanged<bool> onLockChanged;

  @override
  State<TicketPaneHost> createState() => _TicketPaneHostState();
}

class _TicketPaneHostState extends State<TicketPaneHost> {
  late final OrderFlowBloc _orderFlow = widget.createOrderFlow();
  late final CandlesCubit _candles = widget.createCandles(
    widget.instrument.symbol,
  )..load();

  @override
  void dispose() {
    _orderFlow.close();
    _candles.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TicketPage(
      instrument: widget.instrument,
      orderFlow: _orderFlow,
      candles: _candles,
      resolver: widget.resolver,
      embedded: true,
      onLockChanged: widget.onLockChanged,
    );
  }
}
