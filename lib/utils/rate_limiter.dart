import 'dart:async';

/// A robust rate limiter for preventing API spamming.
/// Uses a "cooldown" map to track per-method usage and a "quota" check.
class RateLimiter {
  static final Map<String, DateTime> _methodCooldowns = {};
  
  // Default cooldown for critical write operations (in milliseconds)
  static const int defaultCooldown = 3000; 

  /// Checks if a call is allowed based on a per-key (method/user) cooldown.
  /// Returns null if allowed, or a human-readable error message if blocked.
  static String? check(String key, {int cooldownMs = defaultCooldown}) {
    final now = DateTime.now();
    final lastCall = _methodCooldowns[key];

    if (lastCall != null) {
      final difference = now.difference(lastCall).inMilliseconds;
      if (difference < cooldownMs) {
        final remaining = ((cooldownMs - difference) / 1000).toStringAsFixed(1);
        return "Please wait $remaining more seconds before trying again.";
      }
    }

    // Update the last call timestamp
    _methodCooldowns[key] = now;
    return null;
  }

  /// Helper to wrap async functions with rate limiting.
  /// Throws an exception if the rate limit is exceeded.
  static Future<T> run<T>(String key, Future<T> Function() action, {int cooldownMs = defaultCooldown}) async {
    final error = check(key, cooldownMs: cooldownMs);
    if (error != null) {
      throw RateLimitException(error);
    }
    return await action();
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => message;
}
