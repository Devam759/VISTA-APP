import 'package:flutter/foundation.dart';

/// A lightweight, in-memory TTL cache for the VISTA app.
///
/// Security guarantees:
///   - RAM-only: cleared automatically when the app process is killed.
///   - Explicit wipe via [clearAll] — called on every sign-out so no
///     previous user's data bleeds into the next session.
///   - Security-sensitive fields (isApproved, isAccountActive, role) are
///     NEVER stored here; they are always fetched live from Firestore.
///
/// Usage:
///   final cache = CacheService.instance;
///   cache.set('key', value, ttl: Duration(minutes: 5));
///   final v = cache.get`<String>`('key');
///   cache.invalidate('key');
///   cache.clearAll();
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  final Map<String, _CacheEntry<dynamic>> _store = {};

  // ── Key namespaces ────────────────────────────────────────────────────────

  /// Cache key for a student's attendance list (keyed by UID).
  static String attendanceKey(String uid) => 'attendance_$uid';

  /// Cache key for mess menu on a specific date string (YYYY-MM-DD).
  static String messMenuKey(String dateStr) => 'mess_menu_$dateStr';

  /// Cache key for mess permanent staples.
  static const String messStaplesKey = 'mess_staples';

  /// Cache key for the active weekly PDF metadata.
  static const String messWeeklyPdfKey = 'mess_weekly_pdf';

  // ── Core API ─────────────────────────────────────────────────────────────

  /// Store [value] under [key] with a given [ttl].
  /// After [ttl] elapses, [get] returns null and the entry is purged lazily.
  void set<T>(String key, T value, {required Duration ttl}) {
    _store[key] = _CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    if (kDebugMode) {
      debugPrint('[CacheService] SET $key (expires in ${ttl.inSeconds}s)');
    }
  }

  /// Returns the cached value for [key] if it exists and has not expired.
  /// Returns null if missing or stale (and purges the entry).
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      if (kDebugMode) debugPrint('[CacheService] MISS (expired) $key');
      return null;
    }

    if (kDebugMode) debugPrint('[CacheService] HIT $key');
    return entry.value as T?;
  }

  /// Returns true if a non-expired entry exists for [key].
  bool has(String key) => get<dynamic>(key) != null;

  /// Remove a single entry.
  void invalidate(String key) {
    _store.remove(key);
    if (kDebugMode) debugPrint('[CacheService] INVALIDATED $key');
  }

  /// Remove all entries whose key starts with [prefix].
  void invalidatePrefix(String prefix) {
    final keysToRemove = _store.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keysToRemove) {
      _store.remove(k);
    }
    if (kDebugMode) {
      debugPrint('[CacheService] INVALIDATED ${keysToRemove.length} entries with prefix "$prefix"');
    }
  }

  /// Wipe the entire cache. Called on sign-out to prevent data leakage
  /// between users on a shared device.
  void clearAll() {
    _store.clear();
    if (kDebugMode) debugPrint('[CacheService] CLEARED ALL');
  }
}

// ── Internal entry model ──────────────────────────────────────────────────────

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });
}
