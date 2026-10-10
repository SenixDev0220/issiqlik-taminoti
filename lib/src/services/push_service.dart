import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_service.dart';

/// Handles FCM push notifications.
///
/// Delivery model: a Cloud Function (see functions/index.js) sends a push for
/// every document created in the `notifications` collection — to the `all`
/// topic for broadcasts (empty recipientIds) or to the recipients' saved
/// fcmTokens. Background/killed-state messages are displayed by the system;
/// foreground messages are shown via flutter_local_notifications.
class PushService {
  PushService._();
  static final instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const _channel = AndroidNotificationChannel(
    'issiqlik_main',
    "Issiqlik Ta'minoti",
    description: "Issiqlik Ta'minoti bildirishnomalari",
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    try {
      await _messaging.requestPermission();

      await _local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await _messaging.subscribeToTopic('all');

      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (_) {
      // Push is best-effort — never break app startup over it
      // (e.g. missing Google Play services).
    }
  }

  StreamSubscription<String>? _refreshSub;

  /// Saves this device's token on the user profile and keeps it fresh.
  Future<void> registerToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseService.instance.saveFcmToken(uid, token);
      }
      // Re-arm the refresh listener for the current user only, otherwise a
      // second login on the same device would keep writing the token to the
      // previous user's profile.
      await _refreshSub?.cancel();
      _refreshSub = _messaging.onTokenRefresh.listen(
        (t) => FirebaseService.instance.saveFcmToken(uid, t),
        onError: (_) {},
      );
    } catch (_) {
      // Best-effort.
    }
  }

  /// Call on sign-out: stop broadcasts to this device and detach the token
  /// from the user profile.
  Future<void> unregister(String uid) async {
    try {
      await _refreshSub?.cancel();
      _refreshSub = null;
      await _messaging.unsubscribeFromTopic('all');
      await FirebaseService.instance.clearFcmToken(uid);
      await _messaging.deleteToken();
      // Allow a later login on this device to re-subscribe.
      _inited = false;
    } catch (_) {
      // Best-effort.
    }
  }

  void _showForeground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
