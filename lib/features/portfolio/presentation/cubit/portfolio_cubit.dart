import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';

enum PortfolioStatus { loading, ready, failure }

class PortfolioState extends Equatable {
  const PortfolioState({
    required this.status,
    this.account,
    this.error,
    this.isRefreshing = false,
  });

  static const PortfolioState initial = PortfolioState(
    status: PortfolioStatus.loading,
  );

  final PortfolioStatus status;
  final Account? account;
  final AppException? error;
  final bool isRefreshing;

  @override
  List<Object?> get props => [status, account, error?.code, isRefreshing];
}

/// Cash and positions exactly as the server reports them (SSOT-01). It is
/// refreshed after fills, never computed locally.
class PortfolioCubit extends Cubit<PortfolioState> {
  PortfolioCubit({
    required AccountReader reader,
    required ExceptionMapper mapper,
  }) : _reader = reader,
       _mapper = mapper,
       super(PortfolioState.initial);

  final AccountReader _reader;
  final ExceptionMapper _mapper;

  /// Loads or reloads. Keeps the previous account visible while refreshing
  /// and when a refresh fails.
  Future<void> load() async {
    final previous = state.account;
    emit(
      previous == null
          ? PortfolioState.initial
          : PortfolioState(
              status: PortfolioStatus.ready,
              account: previous,
              isRefreshing: true,
            ),
    );
    try {
      final account = await _reader.getAccount();
      if (isClosed) return;
      emit(PortfolioState(status: PortfolioStatus.ready, account: account));
    } on Object catch (e, st) {
      // Boundary catch (ERR-03).
      if (isClosed) return;
      emit(
        PortfolioState(
          status: previous == null
              ? PortfolioStatus.failure
              : PortfolioStatus.ready,
          account: previous,
          error: _mapper.map(e, st),
        ),
      );
    }
  }
}
