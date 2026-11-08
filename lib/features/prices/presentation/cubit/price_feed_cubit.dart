import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/services/price_feed_service.dart';

/// The app's single view of live prices (SSOT-01). Rows and the ticket read
/// from this cubit; none of them opens its own connection.
///
/// The connection must cover the watchlist symbols AND the position symbols
/// (ADR-0008), so the two sources are unioned here.
class PriceFeedCubit extends Cubit<PriceFeedState> {
  PriceFeedCubit(this._service) : super(_service.current) {
    _subscription = _service.states.listen(emit);
  }

  final PriceFeedService _service;
  late final StreamSubscription<PriceFeedState> _subscription;
  Set<String> _watchlist = const <String>{};
  Set<String> _positions = const <String>{};

  void setWatchlistSymbols(Iterable<String> symbols) {
    _watchlist = Set.unmodifiable(symbols);
    _apply();
  }

  void setPositionSymbols(Iterable<String> symbols) {
    _positions = Set.unmodifiable(symbols);
    _apply();
  }

  /// App went to the background: release the connection.
  void pause() => _service.pause();

  void resume() => _service.resume();

  void _apply() => _service.setSymbols({..._watchlist, ..._positions});

  @override
  Future<void> close() async {
    // Dispose first: it closes the service's own stream. Awaiting a cancel on
    // a subscription of that same broadcast stream can stall the close.
    unawaited(_subscription.cancel());
    await _service.dispose();
    return super.close();
  }
}
