import 'dart:async';

import 'package:pulse/core/errors/retry_policy.dart';
import 'package:pulse/core/utils/clock.dart';
import 'package:pulse/features/prices/domain/entities/price_book.dart';
import 'package:pulse/features/prices/domain/entities/price_feed_state.dart';
import 'package:pulse/features/prices/domain/entities/price_message.dart';
import 'package:pulse/features/prices/domain/repositories/price_stream_source.dart';

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Timing knobs (SSOT-03, ADR-0007, Q2).
class PriceFeedConfig {
  const PriceFeedConfig({
    this.staleAfter = const Duration(seconds: 6),
    this.offlineAfter = const Duration(seconds: 15),
    this.publishInterval = const Duration(milliseconds: 150),
    this.statusCheckInterval = const Duration(seconds: 1),
  });

  final Duration staleAfter;
  final Duration offlineAfter;
  final Duration publishInterval;
  final Duration statusCheckInterval;
}

class _Connection {
  _Connection(this.symbols);

  final Set<String> symbols;
  StreamSubscription<PriceMessage>? subscription;
  bool receivedAny = false;

  Future<void> cancel() async => subscription?.cancel();
}

/// The ONLY owner of the price connection (STR-01).
///
/// Dedupes by `seq`, coalesces bursts before publishing, reconnects with
/// backoff, swaps connections without a gap when symbols change, reports
/// staleness from the silence duration, and releases everything on
/// [pause]/[dispose].
class PriceFeedService {
  PriceFeedService({
    required PriceStreamSource source,
    required Clock clock,
    RetryPolicy? backoff,
    PriceFeedConfig config = const PriceFeedConfig(),
  }) : _source = source,
       _clock = clock,
       _backoff = backoff ?? RetryPolicy(maxAttempts: 1000),
       _config = config;

  final PriceStreamSource _source;
  final Clock _clock;
  final RetryPolicy _backoff;
  final PriceFeedConfig _config;

  final StreamController<PriceFeedState> _controller =
      StreamController<PriceFeedState>.broadcast();

  PriceFeedState _state = PriceFeedState.initial;
  PriceBook _book = PriceBook.empty;
  Set<String> _desired = const <String>{};
  _Connection? _active;
  _Connection? _candidate;
  DateTime? _lastMessageAt;
  DateTime? _sessionStart;
  int _failures = 0;
  bool _paused = false;
  bool _disposed = false;
  Timer? _retryTimer;
  Timer? _publishTimer;
  Timer? _statusTimer;

  PriceFeedState get current => _state;

  /// Broadcast stream of state changes. Read [current] for the initial value.
  Stream<PriceFeedState> get states => _controller.stream;

  void setSymbols(Set<String> symbols) {
    if (_disposed) return;
    final clean = Set<String>.unmodifiable(symbols);
    if (_sameSet(clean, _desired)) return;
    _desired = clean;
    _ensureConnection();
  }

  /// Closes the connection (app in background). Prices stay but go stale.
  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    _cancelAll();
    _publishNow();
  }

  void resume() {
    if (_disposed || !_paused) return;
    _paused = false;
    _failures = 0;
    _sessionStart = _clock.now();
    _ensureConnection();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelAll();
    _publishTimer?.cancel();
    await _controller.close();
  }

  void _ensureConnection() {
    if (_disposed || _paused) return;
    if (_desired.isEmpty) {
      _cancelAll();
      _book = PriceBook.empty;
      _lastMessageAt = null;
      _sessionStart = null;
      _publishNow();
      return;
    }
    _sessionStart ??= _clock.now();
    _startStatusTimer();
    if (_retryTimer != null) return;
    final active = _active;
    if (active == null) {
      _candidate?.cancel();
      _candidate = null;
      _active = _open(_desired);
    } else if (!_sameSet(active.symbols, _desired)) {
      final candidate = _candidate;
      if (candidate == null || !_sameSet(candidate.symbols, _desired)) {
        candidate?.cancel();
        _candidate = _open(_desired);
      }
    } else {
      _candidate?.cancel();
      _candidate = null;
    }
    _publishNow();
  }

  _Connection _open(Set<String> symbols) {
    final connection = _Connection(symbols);
    connection.subscription = _source
        .watch(symbols)
        .listen(
          (message) => _onMessage(connection, message),
          onError: (Object _) => _onClosed(connection),
          onDone: () => _onClosed(connection),
        );
    return connection;
  }

  void _onMessage(_Connection connection, PriceMessage message) {
    if (_disposed) return;
    if (identical(connection, _candidate)) {
      _active?.cancel();
      _active = connection;
      _candidate = null;
      _book = _book.retain(connection.symbols);
    } else if (!identical(connection, _active)) {
      return;
    }
    connection.receivedAny = true;
    _failures = 0;
    _lastMessageAt = _clock.now();
    final next = _book.apply(message);
    if (!identical(next, _book)) {
      _book = next;
      _schedulePublish();
    } else if (_state.status != FeedStatus.live) {
      _publishNow();
    }
  }

  void _onClosed(_Connection connection) {
    if (_disposed) return;
    if (identical(connection, _candidate)) {
      _candidate = null;
      _scheduleRetry();
    } else if (identical(connection, _active)) {
      _active = null;
      _scheduleRetry();
      _publishNow();
    }
  }

  void _scheduleRetry() {
    if (_paused || _retryTimer != null) return;
    _failures++;
    _retryTimer = Timer(_backoff.delayFor(_failures), () {
      _retryTimer = null;
      _ensureConnection();
    });
  }

  void _cancelAll() {
    _active?.cancel();
    _candidate?.cancel();
    _active = null;
    _candidate = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _startStatusTimer() {
    _statusTimer ??= Timer.periodic(_config.statusCheckInterval, (_) {
      if (_computeStatus() != _state.status) _publishNow();
    });
  }

  void _schedulePublish() {
    _publishTimer ??= Timer(_config.publishInterval, () {
      _publishTimer = null;
      _publishNow();
    });
  }

  FeedStatus _computeStatus() {
    final reference = _lastMessageAt ?? _sessionStart;
    if (reference == null) return FeedStatus.connecting;
    final age = _clock.now().difference(reference);
    if (age > _config.offlineAfter) return FeedStatus.offline;
    if (_lastMessageAt == null) return FeedStatus.connecting;
    return age > _config.staleAfter ? FeedStatus.stale : FeedStatus.live;
  }

  void _publishNow() {
    if (_disposed) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    final next = PriceFeedState(
      quotes: _book.quotes,
      status: _computeStatus(),
      isReconnecting:
          !_paused &&
          _desired.isNotEmpty &&
          (_active == null || !_active!.receivedAny),
      lastMessageAt: _lastMessageAt,
    );
    if (next == _state) return;
    _state = next;
    _controller.add(next);
  }
}
