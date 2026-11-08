import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/core/logging/app_logger.dart';
import 'package:pulse/features/portfolio/data/models/account_model.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';
import 'package:pulse/features/portfolio/domain/repositories/account_reader.dart';

class AccountRepositoryImpl implements AccountReader {
  AccountRepositoryImpl({
    required TradingRemoteSource source,
    required RemoteCallGuard guard,
    required AppLogger logger,
  }) : _source = source,
       _guard = guard,
       _logger = logger;

  final TradingRemoteSource _source;
  final RemoteCallGuard _guard;
  final AppLogger _logger;

  @override
  Future<Account> getAccount() async {
    final body = await _guard.retrying(_source.getAccount);
    return AccountModel.fromJson(JsonReader.parse(body)).toEntity(
      onSkipped: (e) => _logger.warn('Skipped invalid position: ${e.field}'),
    );
  }
}
