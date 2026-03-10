import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

// flutter_local_notifications is mobile-only — conditionally imported.
// On web, all usage is already guarded with !kIsWeb so this import
// is only exercised at runtime on mobile.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Only initialised on mobile (inside !kIsWeb guard below).
  // Typed as dynamic so web compiler skips method-signature validation.
  dynamic _localNotifications;

  Future<void> init(String uid) async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');

      if (!kIsWeb) {
        // For iOS/macOS, set the foreground notification presentation options
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Get the token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _firebaseService.updateFcmToken(uid, token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _firebaseService.updateFcmToken(uid, newToken);
      });

      if (!kIsWeb) {
        // Initialize local notifications for foreground messaging (mobile only)
        _localNotifications = FlutterLocalNotificationsPlugin();

        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/launcher_icon');

        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings();

        const InitializationSettings initializationSettings =
            InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsIOS,
            );

        await _localNotifications!.initialize(
          settings: initializationSettings,
        );
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null && !kIsWeb) {
          _showLocalNotification(message.notification!);
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
    if (kIsWeb || _localNotifications == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'vista_notifications',
          'Vista App Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications!.show(
      0,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }

  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      debugPrint('FCM token deleted successfully.');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
