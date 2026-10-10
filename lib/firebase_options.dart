// Generated Firebase options — do not edit manually.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android; // fallback
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDN0bAsklneKrZcJ21QJ-fVWZ_DkdAl4c',
    appId: '1:1043429058035:android:34d49f379b4b223cde1e86',
    messagingSenderId: '1043429058035',
    projectId: 'android-app-63a1c',
    storageBucket: 'android-app-63a1c.firebasestorage.app',
  );
}
