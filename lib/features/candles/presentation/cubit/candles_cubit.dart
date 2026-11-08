import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/features/candles/domain/entities/candle.dart';
import 'package:pulse/features/candles/domain/repositories/candle_reader.dart';

enum CandlesStatus { loading, ready, empty, failure }

class CandlesState extends Equatable {
  const CandlesState({
    required this.status,
    required this.range,
    this.candles = const <Candle>[],
    this.error,
  });

  final CandlesStatus status;
  final CandleRange range;
  final List<Candle> candles;
  final AppException? error;

  @override
  List<Object?> get props => [status, range, candles, error?.code];
}

/// Loads the chart bars of ONE symbol. Changing the range quickly never lets
/// an older response overwrite a newer one.
class CandlesCubit extends Cubit<CandlesState> {
  CandlesCubit({
    required this.symbol,
    required CandleReader reader,
    required ExceptionMapper mapper,
  }) : _reader = reader,
       _mapper = mapper,
       super(
         const CandlesState(
           status: CandlesStatus.loading,
           range: CandleRange.day,
         ),
       );

  final String symbol;
  final CandleReader _reader;
  final ExceptionMapper _mapper;
  int _request = 0;

  Future<void> load([CandleRange? range]) async {
    final target = range ?? state.range;
    final id = ++_request;
    emit(CandlesState(status: CandlesStatus.loading, range: target));
    try {
      final candles = await _reader.getCandles(symbol, target);
      if (isClosed || id != _request) return;
      emit(
        CandlesState(
          status: candles.isEmpty ? CandlesStatus.empty : CandlesStatus.ready,
          range: target,
          candles: candles,
        ),
      );
    } on Object catch (e, st) {
      // Boundary catch (ERR-03).
      if (isClosed || id != _request) return;
      emit(
        CandlesState(
          status: CandlesStatus.failure,
          range: target,
          error: _mapper.map(e, st),
        ),
      );
    }
  }

  /// Folds the live price into the newest bar so the chart's last candle
  /// moves with the market. History itself is only reloaded by [load].
  void applyLivePrice(Decimal price) {
    // A closing ticket may still deliver one last price tick.
    if (isClosed) return;
    if (state.status != CandlesStatus.ready || state.candles.isEmpty) return;
    final last = state.candles.last;
    if (last.close == price) return;
    final updated = Candle(
      time: last.time,
      open: last.open,
      high: price > last.high ? price : last.high,
      low: price < last.low ? price : last.low,
      close: price,
      volume: last.volume,
    );
    emit(
      CandlesState(
        status: CandlesStatus.ready,
        range: state.range,
        candles: [...state.candles.take(state.candles.length - 1), updated],
      ),
    );
  }

  Future<void> setRange(CandleRange range) {
    if (range == state.range && state.status == CandlesStatus.ready) {
      return Future<void>.value();
    }
    return load(range);
  }
}
