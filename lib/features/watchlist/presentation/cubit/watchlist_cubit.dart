import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/watchlist/domain/repositories/watchlist_writer.dart';
import 'package:pulse/features/watchlist/domain/services/watchlist_rules.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';

enum WatchlistStatus { loading, ready, failure }

class WatchlistState extends Equatable {
  const WatchlistState({
    required this.status,
    this.symbols = const <String>[],
    this.instruments = const <String, Instrument>{},
    this.isSaving = false,
    this.error,
    this.saveError,
  });

  static const WatchlistState initial = WatchlistState(
    status: WatchlistStatus.loading,
  );

  final WatchlistStatus status;

  /// What the UI shows (optimistic while a save is in flight).
  final List<String> symbols;
  final Map<String, Instrument> instruments;
  final bool isSaving;

  /// Load failure (status == failure).
  final AppException? error;

  /// Last save/edit failure; the list was rolled back (Q9).
  final AppException? saveError;

  List<WatchlistItem> get items => [
    for (final s in symbols)
      if (instruments[s] != null) WatchlistItem(instruments[s]!),
  ];

  bool get isEmpty => status == WatchlistStatus.ready && symbols.isEmpty;

  WatchlistState copyWith({
    WatchlistStatus? status,
    List<String>? symbols,
    Map<String, Instrument>? instruments,
    bool? isSaving,
    AppException? error,
    AppException? saveError,
    bool clearSaveError = false,
    bool clearError = false,
  }) {
    return WatchlistState(
      status: status ?? this.status,
      symbols: symbols ?? this.symbols,
      instruments: instruments ?? this.instruments,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    symbols,
    instruments,
    isSaving,
    error?.code,
    saveError?.code,
  ];
}

/// Loads and edits the watchlist. Edits are optimistic; saves are serialised
/// and coalesced; a failed save rolls back to the last server-confirmed list.
class WatchlistCubit extends Cubit<WatchlistState> {
  WatchlistCubit({
    required LoadWatchlist loadWatchlist,
    required WatchlistWriter writer,
    required ExceptionMapper mapper,
    WatchlistRules rules = const WatchlistRules(),
  }) : _load = loadWatchlist,
       _writer = writer,
       _mapper = mapper,
       _rules = rules,
       super(WatchlistState.initial);

  final LoadWatchlist _load;
  final WatchlistWriter _writer;
  final ExceptionMapper _mapper;
  final WatchlistRules _rules;

  List<String> _confirmed = const <String>[];
  bool _saving = false;

  /// The list whose save failed, kept so the user can retry it (Q9).
  List<String>? _failedAttempt;

  Future<void> load() async {
    _failedAttempt = null;
    emit(WatchlistState.initial);
    try {
      final loaded = await _load();
      _confirmed = loaded.symbols;
      if (isClosed) return;
      emit(
        WatchlistState(
          status: WatchlistStatus.ready,
          symbols: loaded.symbols,
          instruments: loaded.instruments,
        ),
      );
    } on Object catch (e, st) {
      // Boundary catch (ERR-03): everything becomes an AppException.
      if (isClosed) return;
      emit(
        WatchlistState(
          status: WatchlistStatus.failure,
          error: _mapper.map(e, st),
        ),
      );
    }
  }

  /// Adds [instrument] (data from search) to the end of the list.
  Future<void> add(Instrument instrument) {
    return _edit(
      (symbols) => _rules.add(symbols, instrument.symbol),
      extraInstrument: instrument,
    );
  }

  Future<void> remove(String symbol) {
    return _edit((symbols) => _rules.remove(symbols, symbol));
  }

  /// [newIndex] follows Flutter's ReorderableListView convention.
  Future<void> reorder(int oldIndex, int newIndex) {
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    return _edit((symbols) => _rules.move(symbols, oldIndex, target));
  }

  /// True while a failed save can be retried.
  bool get canRetrySave => _failedAttempt != null;

  /// Re-applies the list whose save failed and saves it again.
  Future<void> retryFailedSave() async {
    final failed = _failedAttempt;
    if (failed == null || state.status != WatchlistStatus.ready) return;
    _failedAttempt = null;
    emit(state.copyWith(symbols: failed, clearSaveError: true));
    await _flush();
  }

  void clearSaveError() {
    if (state.saveError != null) emit(state.copyWith(clearSaveError: true));
  }

  Future<void> _edit(
    List<String> Function(List<String> current) change, {
    Instrument? extraInstrument,
  }) async {
    if (state.status != WatchlistStatus.ready) return;
    final List<String> next;
    try {
      next = change(state.symbols);
    } on AppException catch (e) {
      emit(state.copyWith(saveError: e));
      return;
    }
    if (listEquals(next, state.symbols)) return;
    _failedAttempt = null;
    emit(
      state.copyWith(
        symbols: next,
        instruments: extraInstrument == null
            ? null
            : {...state.instruments, extraInstrument.symbol: extraInstrument},
        clearSaveError: true,
      ),
    );
    await _flush();
  }

  /// Single in-flight save; later edits are coalesced into the next one.
  Future<void> _flush() async {
    if (_saving) return;
    _saving = true;
    if (!isClosed) emit(state.copyWith(isSaving: true));
    List<String>? attempted;
    try {
      while (!isClosed && !listEquals(state.symbols, _confirmed)) {
        final wanted = state.symbols;
        attempted = wanted;
        final saved = await _writer.replaceSymbols(wanted);
        _confirmed = saved;
        if (isClosed) break;
        // Adopt the server's truth only if the user did not edit meanwhile.
        if (listEquals(state.symbols, wanted) && !listEquals(saved, wanted)) {
          emit(state.copyWith(symbols: saved));
        }
      }
      if (!isClosed) emit(state.copyWith(isSaving: false));
    } on Object catch (e, st) {
      // Boundary catch (ERR-03): roll back to the last confirmed list.
      _failedAttempt = attempted;
      if (!isClosed) {
        emit(
          state.copyWith(
            symbols: _confirmed,
            isSaving: false,
            saveError: _mapper.map(e, st),
          ),
        );
      }
    } finally {
      _saving = false;
    }
  }
}
