import 'package:clock/clock.dart' as pkg;

/// Injectable wall clock so staleness/backoff are testable (STR-02).
abstract interface class Clock {
  DateTime now();
}

/// Uses `package:clock`, which `fakeAsync` can fast-forward in tests
/// (plain `DateTime.now()` cannot be faked).
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => pkg.clock.now();
}
