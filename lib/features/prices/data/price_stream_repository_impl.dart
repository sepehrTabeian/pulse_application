import 'package:pulse/core/data/remote/remote_call_guard.dart';
import 'package:pulse/core/data/remote/trading_remote_source.dart';
import 'package:pulse/features/prices/data/models/price_message_parser.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';

class PriceStreamRepositoryImpl implements PriceStreamSource {
  PriceStreamRepositoryImpl({
    required TradingRemoteSource source,
    required RemoteCallGuard guard,
  }) : _source = source,
       _guard = guard;

  final TradingRemoteSource _source;
  final RemoteCallGuard _guard;

  @override
  Stream<PriceMessage> watch(Set<String> symbols) {
    final clean = symbols
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (clean.isEmpty) return const Stream<PriceMessage>.empty();
    return _guard.guardStream(_source.streamPrices(clean)).expand((raw) {
      final message = PriceMessageParser.tryParse(raw);
      return message == null ? const <PriceMessage>[] : [message];
    });
  }
}
