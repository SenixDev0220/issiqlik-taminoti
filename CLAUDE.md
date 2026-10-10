# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter corporate app for Khorazm Issiklik Manbai (boiler house / district heating operator in Khorezm, Uzbekistan). Manages boiler houses, equipment, an operations journal, instructions, drawings, and notifications for employees. All UI text is Uzbek, in two scripts (Cyrillic and Latin). Despite the directory name `androidSdkProj`, this is a standard multi-platform Flutter project; the package name is `khorazm_issiklik_manbai_app`.

## Commands

```bash
flutter pub get                    # install dependencies
flutter run                        # run the app (needs a device/emulator; Firebase must be reachable)
flutter analyze                    # static analysis (flutter_lints defaults)
flutter test                       # run tests
flutter test test/widget_test.dart # run a single test file
dart run flutter_launcher_icons    # regenerate app icons from assets/images/logo.png
```

Note: `test/widget_test.dart` is outdated — it expects old Russian UI strings ("Вход в систему") while the app is now Uzbek-only, and it pumps `App` without Firebase initialization. Don't treat its failure as a regression you introduced.

## Architecture

The backend is entirely Firebase (Auth + Firestore + Storage). There is no local database layer: `drift`, `sqlcipher_flutter_libs`, and the codegen dev-dependencies (`build_runner`, `riverpod_generator`, `drift_dev`) are declared in pubspec.yaml but **unused** — no `.g.dart` files exist and nothing imports drift. Offline support comes from Firestore's offline persistence, enabled with an unlimited cache in `lib/main.dart`. (README.md's mention of Drift/SQLite is stale.)

Data flow for every feature follows the same path:

1. **`lib/src/services/firebase_service.dart`** — a singleton (`FirebaseService.instance`) through which *all* Firestore/Auth/Storage access goes. It holds the collection references, manual `_xxxFromDoc`/`_xxxToMap` mappers, and enum↔string converters. Models are plain Dart classes in `lib/src/domain/models/` with no serialization of their own — when you add a model field, you must also update the mapper pair here.
2. **`lib/src/core/app_state.dart`** — Riverpod providers (classic `StateProvider`/`StreamProvider`, no codegen) wrapping the service streams, plus small `_XxxActions` wrapper classes exposed via `xxxNotifierProvider`. Feature-specific providers live next to their screens in `lib/src/features/<feature>/<feature>_providers.dart`.
3. **Screens** in `lib/src/features/<feature>/` watch the providers.

Routing is a single static `GoRouter` in `lib/app.dart`; every route uses the shared `_slideFade` transition. New screens are registered there. `MaterialApp.router` is keyed by the selected language (`ValueKey(lang)`), so switching language rebuilds the whole app. The app is wrapped in `SessionTimeoutManager` (`lib/src/features/auth/`) for inactivity logout.

### Auth model (non-obvious)

- Users log in with a **login name, not an email**. `FirebaseService._toEmail` maps it to a synthetic email `<login>@khorazm-issiklik.app` for Firebase Auth.
- The **first registered user becomes `admin`/`active`**; everyone else starts as `member`/`pending` and must be approved by an admin (Admin Panel screen). Roles: `admin`, `coAdmin`, `member`; statuses: `active`, `pending`, `blocked`. `attemptLogin` in `auth_providers.dart` rejects pending/blocked users client-side; `firestore.rules` enforces the same server-side.
- Registration cannot query Firestore before sign-in (rules deny unauthenticated reads): login uniqueness relies on Firebase Auth's `email-already-in-use`, and the phone-uniqueness check runs *after* the auth account is created (rolled back on failure). Keep this ordering when touching `register()`.
- Password reset from the login screen runs unauthenticated: it only files a broadcast `system` notification with the login (no user lookup). Admin-initiated resets write a `passwordResets` doc, consumed by the `applyPasswordReset` Cloud Function (`functions/index.js`), which changes the Auth password and deletes the doc.
- Push notifications: `PushService` (lib/src/services/push_service.dart) subscribes every device to FCM topic `all` and saves the token to `users/{uid}.fcmToken`; the `sendNotificationPush` Cloud Function pushes on every new `notifications` doc (empty `recipientIds` → topic broadcast, otherwise per-token). Functions deploy requires the Blaze plan (`firebase deploy --only functions`).
- Session restore happens in `main.dart` before `runApp` by overriding `currentUserProvider`; `currentUserSyncProvider` keeps role/status changes live afterward.

### Firestore specifics

- Collections: `users`, `boilerhouses`, `equipment`, `journal`, `instructions`, `drawings`, `notifications`, `changeLogs` (with a `reactions` subcollection), `audit_log`, `passwordResets`. Security rules live in `firestore.rules` at the repo root with a default-deny catch-all — **adding a collection requires adding a rules block and deploying it** (`firebase deploy --only firestore:rules`; `firebase.json`/`.firebaserc` exist, project `android-app-63a1c`), or all access fails.
- Notifications: empty `recipientIds` means broadcast to everyone. `isRead` is a single flag on the doc, not per-recipient — marking a broadcast read marks it read for all users.
- Seeding: `seedIfEmpty()` runs after login/session-restore and populates empty collections — boiler houses from `lib/src/data/boiler_seed.dart` (real passport data for Urgench city + 11 districts), equipment/instructions/drawings from `lib/src/data/sample_data.dart`.

### Localization

Hand-rolled, not `intl`/arb: `lib/src/core/l10n.dart` defines `AppL10n` with a getter per string, each choosing between Uzbek Cyrillic and Uzbek Latin based on the language code (`uz_cyrl` is default, toggled via `selectedLanguageProvider`). Access it in widgets through `l10nProvider`. Every user-facing string needs both script variants; note that some error strings are also hardcoded (Latin script) inside `FirebaseService`.

### Assets

`assets/images/logo.png` (app icon source) and `assets/schemas/` (per-district boiler house schema images). New assets must be registered in `pubspec.yaml`.
