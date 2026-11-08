import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';
import 'package:pulse/features/portfolio/presentation/cubit/portfolio_cubit.dart';

class _Reader implements AccountReader {
  Object? error;
  Account account = Account(
    currency: 'USD',
    cash: Decimal.fromInt(100),
    positions: const [],
  );

  @override
  Future<Account> getAccount() async {
    final e = error;
    if (e != null) throw e;
    return account;
  }
}

void main() {
  late _Reader reader;
  late PortfolioCubit cubit;

  setUp(() {
    reader = _Reader();
    cubit = PortfolioCubit(
      reader: reader,
      mapper: const PulseApiExceptionMapper(),
    );
  });
  tearDown(() => cubit.close());

  test('starts loading then ready with the account', () async {
    expect(cubit.state.status, PortfolioStatus.loading);

    await cubit.load();

    expect(cubit.state.status, PortfolioStatus.ready);
    expect(cubit.state.account!.cash, Decimal.fromInt(100));
  });

  test('first load failure is a failure state', () async {
    reader.error = const ServiceUnavailableException();

    await cubit.load();

    expect(cubit.state.status, PortfolioStatus.failure);
    expect(cubit.state.error, isA<ServiceUnavailableException>());
  });

  test('a failed refresh keeps the previous account visible', () async {
    await cubit.load();
    reader.error = const ServiceUnavailableException();

    await cubit.load();

    expect(cubit.state.status, PortfolioStatus.ready);
    expect(cubit.state.account, isNotNull);
    expect(cubit.state.error, isNotNull);
  });

  test(
    'a refresh shows the old account with isRefreshing, then the new one',
    () async {
      await cubit.load();
      reader.account = Account(
        currency: 'USD',
        cash: Decimal.fromInt(5),
        positions: const [],
      );
      final states = <PortfolioState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.first.isRefreshing, isTrue);
      expect(states.first.account!.cash, Decimal.fromInt(100));
      expect(states.last.account!.cash, Decimal.fromInt(5));
    },
  );

  test('unknown errors are wrapped', () async {
    reader.error = StateError('x');

    await cubit.load();

    expect(cubit.state.error, isA<UnexpectedException>());
  });

  test('closing while loading does not emit afterwards', () async {
    final future = cubit.load();
    await cubit.close();

    await expectLater(future, completes);
  });
}
