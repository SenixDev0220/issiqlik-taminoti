import 'package:firebase_messaging/firebase_messaging.dart';

/// Spark has no trusted server sender. In-app notifications use Firestore.
/// Do not create tokens, request push permission, or subscribe to a shared topic.
class PushService {
  PushService._();
  static final instance = PushService._();
  static const serverPushAvailable = false;
  Future<void> init() => _removeLegacyRegistration();
  Future<void> registerToken(String uid) => _removeLegacyRegistration();
  Future<void> unregister(String uid) => _removeLegacyRegistration();
  Future<void> _removeLegacyRegistration() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all').timeout(const Duration(seconds: 3));
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Best-effort local cleanup, not a substitute for operator removal of old
      // deployed Functions and stored tokens. Never block logout on push.
    }
  }
}
