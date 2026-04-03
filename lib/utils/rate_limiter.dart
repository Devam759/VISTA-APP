import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, per-key write rate limiter.
///
/// Cooldown timestamps are stored in SharedPreferences so they survive
/// app kills and cold restarts. An attacker cannot bypass them by
/// relaunching the app.
class RateLimiter {
  static const int defaultCooldown = 3000; // ms
  static const String _prefPrefix = 'rate_limiter_';

  /// Check & update the cooldown for [key].
  /// Returns null if allowed. Returns a human-readable error if blocked.
  static Future<String?> check(
    String key, {
    int cooldownMs = defaultCooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = '$_prefPrefix$key';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastMs = prefs.getInt(prefKey) ?? 0;
    final diff = now - lastMs;

    if (diff < cooldownMs) {
      final remaining = ((cooldownMs - diff) / 1000).toStringAsFixed(1);
      return 'Please wait $remaining more second(s) before trying again.';
    }

    await prefs.setInt(prefKey, now);
    return null;
  }

  /// Wrap an async action with a rate-limit check.
  /// Throws [RateLimitException] if the cooldown has not elapsed.
  static Future<T> run<T>(
    String key,
    Future<T> Function() action, {
    int cooldownMs = defaultCooldown,
  }) async {
    final error = await check(key, cooldownMs: cooldownMs);
    if (error != null) throw RateLimitException(error);
    return await action();
  }
}

class RateLimitException implements Exception {
  final String message;
  const RateLimitException(this.message);
  @override
  String toString() => message;
}

/// Tracks failed login attempts and enforces exponential back-off lockouts.
///
/// Thresholds:
///   5  failures → locked for 15 minutes
///   10 failures → locked for 1 hour
///   15+ failures → locked for 24 hours
///
/// All state is persisted in SharedPreferences so that kill-and-reopen
/// does not reset the counter.
class LoginThrottle {
  static const String _failKey       = 'login_fail_count_';
  static const String _lockUntilKey  = 'login_lock_until_';

  static const int _tier1Threshold = 5;
  static const int _tier2Threshold = 10;
  static const int _tier3Threshold = 15;

  static const Duration _tier1Lock  = Duration(minutes: 15);
  static const Duration _tier2Lock  = Duration(hours: 1);
  static const Duration _tier3Lock  = Duration(hours: 24);

  /// Returns null if login is allowed, or a human-readable lockout message.
  static Future<String?> checkLockout(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sanitizeKey(identifier);
    final lockUntilMs = prefs.getInt('$_lockUntilKey$key') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < lockUntilMs) {
      final remaining = Duration(milliseconds: lockUntilMs - now);
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      return 'Too many failed attempts. Try again in ${mins}m ${secs}s.';
    }
    return null;
  }

  /// Call after a successful login to clear failure counts.
  static Future<void> onSuccess(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sanitizeKey(identifier);
    await prefs.remove('$_failKey$key');
    await prefs.remove('$_lockUntilKey$key');
    debugPrint('[LoginThrottle] Cleared failure count for $key after success.');
  }

  /// Call after each failed login attempt.
  static Future<void> onFailure(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sanitizeKey(identifier);
    final fails = (prefs.getInt('$_failKey$key') ?? 0) + 1;
    await prefs.setInt('$_failKey$key', fails);

    Duration? lockDuration;
    if (fails >= _tier3Threshold) {
      lockDuration = _tier3Lock;
    } else if (fails >= _tier2Threshold) {
      lockDuration = _tier2Lock;
    } else if (fails >= _tier1Threshold) {
      lockDuration = _tier1Lock;
    }

    if (lockDuration != null) {
      final lockUntil =
          DateTime.now().add(lockDuration).millisecondsSinceEpoch;
      await prefs.setInt('$_lockUntilKey$key', lockUntil);
      debugPrint(
        '[LoginThrottle] Account "$key" locked for '
        '${lockDuration.inMinutes} minutes after $fails failures.',
      );
    } else {
      debugPrint('[LoginThrottle] Failure #$fails for "$key".');
    }
  }

  /// Returns how many seconds remain in the lockout (0 if not locked).
  static Future<int> lockoutRemainingSeconds(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sanitizeKey(identifier);
    final lockUntilMs = prefs.getInt('$_lockUntilKey$key') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= lockUntilMs) return 0;
    return ((lockUntilMs - now) / 1000).ceil();
  }

  // Normalize identifier to a safe SharedPreferences key.
  static String _sanitizeKey(String identifier) {
    return identifier
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9@._+\-]'), '_');
  }
}
