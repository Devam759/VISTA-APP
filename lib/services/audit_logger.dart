import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Security event types written to the append-only `audit_logs` collection.
enum AuditEvent {
  loginSuccess,
  loginFailed,
  loginLocked,
  logout,
  securityViolation,
  statusChange,
  escalation,
  roleRejected,
}

/// Centralized security audit logger.
///
/// All events land in the `audit_logs` Firestore collection which has
/// append-only rules (no update/delete) and is write-only for clients
/// (read access is denied to all client roles including chiefWarden).
///
/// Design decisions:
///   • Writes are fire-and-forget (never await) in non-critical paths to
///     avoid blocking the main UX flow.
///   • Failures are swallowed after a debug print — a broken audit log
///     should never crash the app, but it should be loud in dev mode.
///   • We use lazy Firestore access to avoid calling it before initializeApp().
class AuditLogger {
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );

  /// Log a security event on behalf of the authenticated [uid].
  static Future<void> log({
    required String uid,
    required AuditEvent event,
    String? detail,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final payload = <String, dynamic>{
        'uid': uid,
        'event': event.name,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
        'detail': detail,                  // null is fine — Firestore skips null fields
        if (extra != null) ...extra,
      };
      // Non-blocking write.
      unawaited(_db.collection('audit_logs').add(payload));
    } catch (e) {
      // Never let audit failures crash the app.
      debugPrint('[AuditLogger] Failed to write event ${event.name}: $e');
    }
  }

  /// Log an event not yet tied to a Firebase Auth user (e.g., pre-login failure).
  /// Uses the Firebase Auth anonymous UID if available, otherwise "anonymous".
  static Future<void> logAnonymous({
    required AuditEvent event,
    String? detail,
    Map<String, dynamic>? extra,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return log(uid: uid, event: event, detail: detail, extra: extra);
  }

  /// Fire-and-forget helper — call without await in hot paths.
  static void logSync({
    required String uid,
    required AuditEvent event,
    String? detail,
  }) {
    // ignore: discarded_futures
    log(uid: uid, event: event, detail: detail);
  }
}

/// Extension to silence the "discarded_futures" lint on intentional
/// fire-and-forget calls (e.g., audit logging on the hot path).
void unawaited(Future<dynamic> future) {
  future.then((_) {}, onError: (Object e) {
    debugPrint('[unawaited] Swallowed error: $e');
  });
}
