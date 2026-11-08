import 'package:get_it/get_it.dart';
import 'package:pulse/core/data/errors/pulse_api_exception_mapper.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/core/utils/id_generator.dart';

/// Composition root for core services (DI-01, DI-02). Idempotent so hot
/// restarts and repeated calls never double-register.
void configureCoreDependencies(GetIt di) {
  if (di.isRegistered<AppLogger>()) return;

  di
    ..registerLazySingleton<AppLogger>(DeveloperLogger.new)
    ..registerLazySingleton<ExceptionMapper>(PulseApiExceptionMapper.new)
    ..registerLazySingleton<ErrorMessageResolver>(
      DefaultErrorMessageResolver.new,
    )
    ..registerLazySingleton<IdGenerator>(UuidV4Generator.new)
    ..registerFactory<RetryPolicy>(RetryPolicy.new);
}
