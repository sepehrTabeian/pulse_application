import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/features/instruments/domain/entities/asset_class.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_catalog.dart';
import 'package:pulse/features/orders/domain/repositories/order_history.dart';
import 'package:pulse/features/trading/domain/entities/order.dart';

enum OrdersStatus { loading, ready, failure }

/// Which order statuses the list shows. `all` also shows statuses this app
/// version does not know yet.
enum OrderFilter { all, filled, pending, working, rejected, cancelled }

class OrdersState extends Equatable {
  const OrdersState({
    required this.status,
    this.orders = const <Order>[],
    this.instruments = const <String, Instrument>{},
    this.filter = OrderFilter.all,
    this.assetClass,
    this.error,
    this.refreshError,
  });

  static const OrdersState initial = OrdersState(status: OrdersStatus.loading);

  final OrdersStatus status;
  final List<Order> orders;
  final Map<String, Instrument> instruments;
  final OrderFilter filter;

  /// Null = stocks and crypto.
  final AssetClass? assetClass;

  /// The first load failed.
  final AppException? error;

  /// A refresh failed; the old list stays visible. Shown once, then cleared.
  final AppException? refreshError;

  List<Order> get _byAsset => assetClass == null
      ? orders
      : [
          for (final o in orders)
            if (assetClassOf(o.symbol, instruments[o.symbol]) == assetClass) o,
        ];

  List<Order> get visible => [
    for (final o in _byAsset)
      if (_matches(filter, o.status)) o,
  ];

  /// Count shown next to a status; respects the asset-class selection.
  int count(OrderFilter f) =>
      _byAsset.where((o) => _matches(f, o.status)).length;

  static bool _matches(OrderFilter f, OrderStatus s) => switch (f) {
    OrderFilter.all => true,
    OrderFilter.filled => s == OrderStatus.filled,
    OrderFilter.pending => s == OrderStatus.pending,
    OrderFilter.working => s == OrderStatus.working,
    OrderFilter.rejected => s == OrderStatus.rejected,
    OrderFilter.cancelled => s == OrderStatus.cancelled,
  };

  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    Map<String, Instrument>? instruments,
    OrderFilter? filter,
    AssetClass? assetClass,
    bool clearAssetClass = false,
    AppException? error,
    AppException? refreshError,
    bool clearError = false,
    bool clearRefreshError = false,
  }) => OrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    instruments: instruments ?? this.instruments,
    filter: filter ?? this.filter,
    assetClass: clearAssetClass ? null : assetClass ?? this.assetClass,
    error: clearError ? null : error ?? this.error,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );

  @override
  List<Object?> get props => [
    status,
    orders,
    instruments,
    filter,
    assetClass,
    error?.code,
    refreshError?.code,
  ];
}

/// The order history: what the server lists (filled, queued, under review)
/// plus the refusals the app recorded itself.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required OrderHistoryReader reader,
    required RejectedOrderLog rejectedLog,
    required InstrumentCatalog catalog,
    required ExceptionMapper mapper,
  }) : _reader = reader,
       _rejectedLog = rejectedLog,
       _catalog = catalog,
       _mapper = mapper,
       super(OrdersState.initial);

  final OrderHistoryReader _reader;
  final RejectedOrderLog _rejectedLog;
  final InstrumentCatalog _catalog;
  final ExceptionMapper _mapper;
  int _request = 0;

  /// Loads or reloads. Keeps the previous list visible while refreshing and
  /// when a refresh fails.
  Future<void> load() async {
    final id = ++_request;
    final hadData = state.status == OrdersStatus.ready;
    if (!hadData) emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final served = await _reader.getOrders();
      final rejected = await _readRejected();
      final instruments = await _readInstruments();
      if (isClosed || id != _request) return;
      emit(
        state.copyWith(
          status: OrdersStatus.ready,
          orders: _merge(served, rejected),
          instruments: instruments ?? state.instruments,
          clearError: true,
        ),
      );
    } on Object catch (e, st) {
      // Boundary catch (ERR-03).
      if (isClosed || id != _request) return;
      final error = _mapper.map(e, st);
      emit(
        hadData
            ? state.copyWith(refreshError: error)
            : state.copyWith(status: OrdersStatus.failure, error: error),
      );
    }
  }

  /// A damaged or unreadable local record never hides the server's orders.
  Future<List<Order>> _readRejected() async {
    try {
      return await _rejectedLog.loadAll();
    } on AppException {
      return const <Order>[];
    }
  }

  /// Types and units are a nicety: without the catalogue the list still shows.
  Future<Map<String, Instrument>?> _readInstruments() async {
    try {
      final all = await _catalog.getInstruments();
      return {for (final i in all) i.symbol: i};
    } on AppException {
      return null;
    }
  }

  static List<Order> _merge(List<Order> served, List<Order> rejected) {
    final known = {for (final o in served) o.clientOrderId};
    final all = [
      ...served,
      for (final o in rejected)
        if (!known.contains(o.clientOrderId)) o,
    ];
    // Newest first; orders without a time keep their relative order last.
    final dated = all.where((o) => o.createdAt != null).toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return [...dated, ...all.where((o) => o.createdAt == null)];
  }

  void setFilter(OrderFilter filter) {
    if (filter != state.filter) emit(state.copyWith(filter: filter));
  }

  void setAssetClass(AssetClass? assetClass) {
    if (assetClass == state.assetClass) return;
    emit(
      assetClass == null
          ? state.copyWith(clearAssetClass: true)
          : state.copyWith(assetClass: assetClass),
    );
  }

  void clearRefreshError() {
    if (state.refreshError != null) {
      emit(state.copyWith(clearRefreshError: true));
    }
  }
}
