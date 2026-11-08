/// Stable machine-readable error codes. Server codes mirror the pulse_api
/// contract; client codes are produced on the device.
abstract final class ErrorCodes {
  // Server (pulse_api contract)
  static const String invalidRequest = 'INVALID_REQUEST';
  static const String invalidQuantity = 'INVALID_QUANTITY';
  static const String invalidPrice = 'INVALID_PRICE';
  static const String duplicateSymbol = 'DUPLICATE_SYMBOL';
  static const String invalidRange = 'INVALID_RANGE';
  static const String unknownSymbol = 'UNKNOWN_SYMBOL';
  static const String orderNotFound = 'ORDER_NOT_FOUND';
  static const String idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const String insufficientFunds = 'INSUFFICIENT_FUNDS';
  static const String insufficientPosition = 'INSUFFICIENT_POSITION';
  static const String tradingHalted = 'TRADING_HALTED';
  static const String watchlistFull = 'WATCHLIST_FULL';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';

  /// Used when the server sends an empty/missing code.
  static const String unknown = 'UNKNOWN';

  // Client
  static const String validation = 'VALIDATION';
  static const String parsing = 'PARSING';
  static const String requestTimeout = 'REQUEST_TIMEOUT';
  static const String streamDisconnected = 'STREAM_DISCONNECTED';
  static const String storage = 'STORAGE';
  static const String unexpected = 'UNEXPECTED';
}
