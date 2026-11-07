# Issiqlik Ta'minoti

[Русский](README.md) · [O'zbekcha](README_UZ.md) · [English](README_EN.md)

Flutter workplace app for district-heating staff: boiler houses, equipment, journal entries, instructions, shifts and private in-app notifications. Uzbek Cyrillic/Latin interface, persisted light/dark appearance and responsive Liquid Glass navigation.

## Current behavior (1.2.1)

- Firebase Auth + Firestore Rules operate on Spark; ordinary text workflows do not require Blaze or Cloud Functions.
- **Every registration starts as member/pending.** A trusted operator explicitly provisions the first administrator. Registration order never grants privileges.
- Authorization uses server-managed `access/{uid}`. Private account data, managerial directory and sanitized staff profiles are separate.
- Journal edits have immutable before-image history. Reference entities and shifts are admin-only **archive** operations, never client physical deletion; archive receipts preserve previous records.
- Notifications are exact-recipient inbox records. Background push, confidential uploads and in-app administrator password resets are not available in this Spark configuration.
- Language/theme preferences are local appearance settings only. Credentials and grants are never stored in SharedPreferences; persistent confidential Firestore caching is disabled.
- Malformed business records are omitted with a warning; malformed authorization always fails closed. Login distinguishes network, permission, invalid credentials, pending and revoked session failures.

## Develop

Flutter 3.47.6 / Dart 3.13+, Android SDK, Node 24.12+ and Java 21 for Firebase emulators:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
npm ci --ignore-scripts
npm run test:security
npm run test:operator
```

On Windows without desktop symlink privileges use process-scoped `FLUTTER_WINDOWS=false FLUTTER_LINUX=false` before Flutter commands in Git Bash. Do not bypass failed platform generation with `--no-pub`; Android plugin registration is checked before build.

CI runs Flutter analysis/tests, an explicitly labelled **debug/test APK** build, emulator rules tests, offline operator tests, dependency auditing and enforced Gitleaks history/source scans. No signing credentials are provided to CI.

## Release and deployment

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols/1.2.1
```

Release requires a private external keystore and ignored `android/key.properties`; there is **no debug-signing fallback**. Preserve the signing key/password and symbol maps outside Git.

For a new Firebase project, replace its client configuration, review `.firebaserc`, establish an explicitly reviewed administrator, migrate legacy data and deploy tested rules/indexes in a controlled rollout. Never deploy blindly to the original project. See [operator guide](security/OPERATOR.md), [security notes](security/README.md) and [data contract](security/contract.md).

The owner previously selected and activated an administrator manually; no account UID/email is hardcoded. `tools/operator.cjs` provides reproducible ADC-based, dry-run-first provisioning with private backups and explicit target confirmation. Legacy notification migration is a private plan requiring explicitly reviewed recipients, not automatic broadcast.

Retired seed data and schemas were removed from the current source tree after private backup. Their historical public Git copies are not retroactively erased. Auth recovery/deprovisioning remains an identity-verified operator task. Android is the configured target; other platforms require separate Firebase provisioning and release validation. App Check enforcement/API key restrictions, Auth quotas and native dependency security are not guaranteed by a successful build.

Firebase client API keys are public configuration, not service-account secrets. Never commit private keys, OAuth tokens, passwords, keystores, production exports or signing files.

License: [MIT](LICENSE).
