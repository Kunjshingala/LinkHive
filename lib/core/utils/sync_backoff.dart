/// Deterministic exponential retry policy for durable sync operations.
class SyncBackoff {
  SyncBackoff._();

  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(hours: 1);

  static Duration delayForAttempt(int attemptCount) {
    if (attemptCount <= 0) return Duration.zero;

    final exponent = attemptCount > 16 ? 16 : attemptCount - 1;
    final delay = Duration(
      milliseconds: baseDelay.inMilliseconds * (1 << exponent),
    );
    return delay > maxDelay ? maxDelay : delay;
  }
}
