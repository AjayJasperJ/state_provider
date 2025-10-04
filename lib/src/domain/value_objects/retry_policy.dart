import '../entities/app_error.dart';

/// Defines how cached requests are retried when replaying from the queue.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(seconds: 2),
    this.backoffFactor = 2.0,
    this.maxBackoff = const Duration(minutes: 1),
    this.retryServerErrors = true,
  }) : assert(maxAttempts >= 1);

  final int maxAttempts;
  final Duration initialBackoff;
  final double backoffFactor;
  final Duration maxBackoff;
  final bool retryServerErrors;

  Duration backoffForAttempt(int attempt) {
    if (attempt <= 1) return initialBackoff;
    final multiplier = backoffFactor <= 1 ? 1 : backoffFactor;
    var delay = initialBackoff;
    for (var i = 1; i < attempt; i++) {
      delay *= multiplier;
      if (delay >= maxBackoff) {
        return maxBackoff;
      }
    }
    return delay > maxBackoff ? maxBackoff : delay;
  }

  bool shouldRetry(AppError error, int attempt) {
    if (attempt >= maxAttempts) return false;
    switch (error.type) {
      case AppErrorType.network:
      case AppErrorType.timeout:
        return true;
      case AppErrorType.server:
        return retryServerErrors;
      default:
        return false;
    }
  }
}
