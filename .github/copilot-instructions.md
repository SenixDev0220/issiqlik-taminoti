# Copilot instructions

## Project

Issiqlik Ta'minoti is a Flutter application for boiler-house and district-heating operations in Khorezm, Uzbekistan. The main target is Android. User-facing Uzbek is available in Cyrillic and Latin scripts.

## Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/firestore_sync_tracker_test.dart
flutter build apk --release
```

Android SDK and JDK 17 are required for an APK build. Local SDK paths belong in the ignored `android/local.properties`; never commit that file.

## Architecture and conventions

- `lib/src/services/firebase_service.dart` is the single entry point for Firebase Auth, Firestore and Storage access. When changing a Firestore-backed model, update its document mapper here as well as the model.
- `lib/src/core/app_state.dart` contains shared Riverpod state and actions. Feature-specific providers live alongside their screens in `lib/src/features/<feature>/`.
- `lib/src/domain/models/` contains plain Dart models. Serialization is handled by `FirebaseService`, not generated model code.
- `lib/app.dart` owns the shared GoRouter and page transitions. Register application screens there.
- Localization is hand-written in `lib/src/core/l10n.dart`. Add every user-visible string in both Uzbek Cyrillic and Uzbek Latin; read it through `l10nProvider`.
- Firestore persistence is configured in `lib/main.dart`. Text writes use the Firestore SDK offline queue and sync tracker. File/Storage uploads and Firebase Auth/Cloud Function operations are not guaranteed offline.
- Firestore rules are in `firestore.rules` and default-deny unspecified collections. Update the rules whenever adding a collection or subcollection.
- The first registration against an empty database becomes an active administrator; subsequent accounts start pending. Preserve the Firebase Auth / Firestore ordering in registration.
- `lib/src/core/app_theme.dart` is the source of truth for the Liquid Glass palette and Material component themes. Shared screen backgrounds, cards, and bottom navigation are in `lib/src/core/glass.dart`; feature screens are wrapped by `GlassScaffold`.
- The home dashboard in `lib/src/features/home/home_screen.dart` groups shortcuts and operational modules using existing providers. Derive displayed metrics from live models; do not hardcode operational data.
- Keep tab-indicator motion transform-based and isolated by `RepaintBoundary`; avoid animated backdrop blur or full-screen opacity layers that require expensive GPU compositing on low-end Android devices.
- Do not add generated Flutter output, APKs, local SDK configuration, signing keys, Firebase service-account files or IDE-local settings to commits.

## Verification

The GitHub Actions workflow runs `flutter analyze --fatal-infos`, `flutter test`, and an Android release APK build on pushes and pull requests to `main`.
