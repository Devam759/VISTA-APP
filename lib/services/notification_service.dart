import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> init(String uid) async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');

      // For iOS/macOS, set the foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get the token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: \$token');
        // Save the token to Firestore
        await _firebaseService.updateFcmToken(uid, token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _firebaseService.updateFcmToken(uid, newToken);
      });

      // Initialize local notifications for foreground messaging
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');

        if (message.notification != null) {
          _showLocalNotification(message.notification!);
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
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

    await _localNotificationsPlugin.show(
      id: 0,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
