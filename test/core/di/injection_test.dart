import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/di/injection.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/core/utils/id_generator.dart';

void main() {
  late GetIt di;

  setUp(() => di = GetIt.asNewInstance());
  tearDown(() => di.reset());

  test('registers core services by interface', () {
    configureCoreDependencies(di);

    expect(di<AppLogger>(), isA<DeveloperLogger>());
    expect(di<ExceptionMapper>(), isA<PulseApiExceptionMapper>());
    expect(di<ErrorMessageResolver>(), isA<DefaultErrorMessageResolver>());
    expect(di<IdGenerator>(), isA<UuidV4Generator>());
  });

  test('singletons are shared and RetryPolicy is a new instance each time', () {
    configureCoreDependencies(di);

    expect(di<AppLogger>(), same(di<AppLogger>()));
    expect(di<ExceptionMapper>(), same(di<ExceptionMapper>()));
    expect(di<RetryPolicy>(), isNot(same(di<RetryPolicy>())));
  });

  test('configuring twice is safe and keeps existing instances', () {
    configureCoreDependencies(di);
    final first = di<AppLogger>();

    configureCoreDependencies(di);

    expect(di<AppLogger>(), same(first));
  });

  test('resolving an unregistered type fails loudly', () {
    expect(() => di<AppLogger>(), throwsA(anything));
  });
}
