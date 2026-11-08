import 'package:pulse/features/prices/domain/entities/price_message.dart';

/// Opens ONE live price connection for [symbols]. Single-subscription.
///
/// Errors are `AppException` (a drop is `StreamDisconnectedException`),
/// after which the stream closes. No auto-reconnect: the caller reconnects.
/// Malformed/unknown messages are dropped, never emitted as errors.
abstract interface class PriceStreamSource {
  Stream<PriceMessage> watch(Set<String> symbols);
}
