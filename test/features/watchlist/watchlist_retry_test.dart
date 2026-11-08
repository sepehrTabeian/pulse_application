import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/watchlist/domain/use_cases/load_watchlist.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';

import '../../support/fakes.dart';
import '../../support/page_harness.dart';

void main() {
  late FakeBackend backend;
  late WatchlistCubit cubit;

  setUp(() async {
    backend = FakeBackend(watchlist: ['AAPL', 'HALT']);
    cubit = WatchlistCubit(
      loadWatchlist: LoadWatchlist(reader: backend, catalog: backend),
      writer: backend,
      mapper: const PulseApiExceptionMapper(),
    );
    await cubit.load();
  });
  tearDown(() => cubit.close());

  test('nothing to retry before any failure', () async {
    expect(cubit.canRetrySave, isFalse);

    await cubit.retryFailedSave();

    expect(backend.puts, isEmpty);
  });

  test('after a failed save, retry re-applies the edit and saves it', () async {
    backend.putError = const ServiceUnavailableException();
    await cubit.remove('AAPL');
    expect(cubit.state.symbols, ['AAPL', 'HALT'], reason: 'rolled back');
    expect(cubit.canRetrySave, isTrue);

    backend.putError = null;
    await cubit.retryFailedSave();

    expect(cubit.state.symbols, ['HALT']);
    expect(backend.server, ['HALT']);
    expect(cubit.state.saveError, isNull);
    expect(cubit.canRetrySave, isFalse);
  });

  test('retry survives clearing the visible error (snackbar shown)', () async {
    backend.putError = const ServiceUnavailableException();
    await cubit.remove('AAPL');
    cubit.clearSaveError();

    backend.putError = null;
    await cubit.retryFailedSave();

    expect(backend.server, ['HALT']);
  });

  test(
    'a retry that fails again rolls back again and stays retryable',
    () async {
      backend.putError = const ServiceUnavailableException();
      await cubit.remove('AAPL');

      await cubit.retryFailedSave();

      expect(cubit.state.symbols, ['AAPL', 'HALT']);
      expect(cubit.state.saveError, isA<ServiceUnavailableException>());
      expect(cubit.canRetrySave, isTrue);
    },
  );

  test('a newer edit invalidates the old retry (no stale overwrite)', () async {
    backend.putError = const ServiceUnavailableException();
    await cubit.remove('AAPL');
    backend.putError = null;

    await cubit.add(testInstrument(symbol: 'BTC'));

    expect(cubit.canRetrySave, isFalse);
    await cubit.retryFailedSave();
    expect(backend.server, ['AAPL', 'HALT', 'BTC']);
  });

  test('reloading clears the retry', () async {
    backend.putError = const ServiceUnavailableException();
    await cubit.remove('AAPL');

    await cubit.load();

    expect(cubit.canRetrySave, isFalse);
  });

  test('local rejections (duplicates) are not retryable', () async {
    await cubit.add(testInstrument(symbol: 'AAPL'));

    expect(cubit.state.saveError, isA<ValidationException>());
    expect(cubit.canRetrySave, isFalse);
  });
}
