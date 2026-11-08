import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pulse/core/bloc/event_transformers.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/domain/repositories/instrument_searcher.dart';

class SearchQueryChanged {
  const SearchQueryChanged(this.query);

  final String query;
}

enum SearchStatus { idle, loading, results, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const <Instrument>[],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<Instrument> results;
  final AppException? error;

  @override
  List<Object?> get props => [status, query, results, error?.code];
}

/// Instrument search. Debounce (RxDart) + restartable (BLOC-03, Q10): only
/// the latest query is searched and an older response can never overwrite a
/// newer one.
class SearchBloc extends Bloc<SearchQueryChanged, SearchState> {
  SearchBloc({
    required InstrumentSearcher searcher,
    required ExceptionMapper mapper,
    Duration debounce = const Duration(milliseconds: 300),
  }) : _searcher = searcher,
       _mapper = mapper,
       super(const SearchState()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable<SearchQueryChanged>(debounce),
    );
  }

  final InstrumentSearcher _searcher;
  final ExceptionMapper _mapper;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }
    emit(SearchState(status: SearchStatus.loading, query: query));
    try {
      final results = await _searcher.search(query);
      emit(
        SearchState(
          status: SearchStatus.results,
          query: query,
          results: results,
        ),
      );
    } on Object catch (e, st) {
      // Boundary catch (ERR-03).
      emit(
        SearchState(
          status: SearchStatus.failure,
          query: query,
          error: _mapper.map(e, st),
        ),
      );
    }
  }
}
