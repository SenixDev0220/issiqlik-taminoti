import 'package:firebase_messaging/firebase_messaging.dart';

/// Legacy cleanup only. Spark in-app messages never depend on this operation.
class PushService {
  PushService._();
  static final instance = PushService._();
  static const serverPushAvailable = false;
  Future<void>? _cleanup;
  bool _completed = false;

  Future<void> init() => _removeLegacyRegistration();
  Future<void> unregister(String uid) => _removeLegacyRegistration();

  Future<void> _removeLegacyRegistration() {
    if (_completed) return Future<void>.value();
    return _cleanup ??= _runCleanup().whenComplete(() => _cleanup = null);
  }

  Future<void> _runCleanup() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all').timeout(const Duration(seconds: 3));
    } catch (_) {
      // Device token deletion is still attempted if topic cleanup failed.
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 3));
      _completed = true;
    } catch (_) {
      // Retry at a later login; this is not an authorization or logout gate.
    }
  }
}
