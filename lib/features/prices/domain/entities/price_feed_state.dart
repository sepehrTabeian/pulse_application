import 'package:equatable/equatable.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';

/// How trustworthy the displayed prices are right now (ADR-0007).
enum FeedStatus {
  /// No message received yet in this session.
  connecting,

  /// Messages (ticks or heartbeats) are arriving.
  live,

  /// Silence longer than the stale threshold: prices may be old.
  stale,

  /// Silence longer than the offline threshold: treat as disconnected.
  offline,
}

/// Immutable snapshot published by the price feed.
class PriceFeedState extends Equatable {
  const PriceFeedState({
    required this.quotes,
    required this.status,
    required this.isReconnecting,
    this.lastMessageAt,
  });

  static const PriceFeedState initial = PriceFeedState(
    quotes: <String, PriceQuote>{},
    status: FeedStatus.connecting,
    isReconnecting: false,
  );

  final Map<String, PriceQuote> quotes;
  final FeedStatus status;

  /// True while no healthy connection exists and we are trying to get one.
  final bool isReconnecting;
  final DateTime? lastMessageAt;

  @override
  List<Object?> get props => [quotes, status, isReconnecting, lastMessageAt];
}
