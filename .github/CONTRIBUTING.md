# Contributing

Thanks for helping improve Issiqlik Ta'minoti.

## Before submitting a change

1. Install the Flutter SDK required by `pubspec.yaml`; configure Android SDK and JDK 17 for Android builds.
2. Configure your own Firebase project if a change needs live authentication, Firestore, Storage or messaging.
3. Run `flutter pub get`, `flutter analyze` and `flutter test`.
4. For Android changes, run `flutter build apk --release`.

## Project-specific expectations

- User-facing strings belong in `lib/src/core/l10n.dart` and must support both Uzbek Cyrillic and Uzbek Latin.
- Route registration belongs in `lib/app.dart`; preserve the existing shared transition.
- Firebase access belongs in `FirebaseService`. Keep Firestore model mappers and Firestore rules in sync with schema changes.
- Do not assume Storage uploads, account creation or Cloud Function actions work offline; Firestore's text-write queue does not make those operations offline-capable.
- Never include local SDK paths, generated build output, Android signing material or Firebase service-account credentials in a change.

GitHub Actions runs analysis, tests and a release APK build for pull requests targeting `main`.
