# Spark hardening and release notes

## Scope

Source: the owner's latest working tree, including existing uncommitted dashboard, responsive UI and Android icon changes. These changes were preserved before editing. Version: 1.2.0+5. No production Firebase deployment, account modification, billing upgrade or automatic administrator selection was performed.

## Implemented

- Fixed member/pending registration with atomically consistent access/private/directory/profile/phone-claim documents. Existing Auth-only signup can be retried with its password; ambiguous commits never delete Auth as rollback.
- Trusted `access/{uid}` role/status/session cutoff; ordinary users cannot elevate themselves. Active admins manage only non-admin users; privileged admin promotion remains an external operator action.
- Private account data separated from a sanitized directory; FCM tokens and plaintext-password reset queue are no longer client data flows.
- Active/assigned-house authorization, field allowlists, types, lengths, linked equipment/operator checks, owner-bound authorship.
- Journal updates and tombstone deletion require atomic immutable history containing the exact previous record. Other activity logs are client-reported, not trusted server audit.
- Exact-recipient in-app notifications; ordinary users cannot send system or mass notifications. UI fanout is bounded but a trusted manager can still make multiple requests; Rules-only mode is not a global rate limiter.
- No topic broadcast sender or deployed Functions in this configuration. Own Auth password change retained. Identity-verified recovery and account deletion are operator-assisted.
- Storage rules deny access until a private file workflow is designed. Historical schemas remain local/repository history but are not bundled into the release APK; files are not automatically migrated or deleted.
- Server validation on session restore, no persistent confidential Firestore cache, invalidated routes on lost access, no raw exception/stack logging in release.
- Latest launcher icon preserved. Large-text responsive wrapping, centered tablet content, keyboard-aware forms, reduced-motion behavior, bounded image cache; unused packages removed.
- Release requires a private external signing configuration; no debug fallback. Android plugin-registration preBuild guard prevents the earlier missing-registrant startup bug.

## Validation

Before the final requested stop on additional tests: 22 Flutter tests passed (including phone/tablet/landscape/large-text cases); 21 Firebase Emulator scenario groups passed. Additional registration retry/legacy-authority/assignment-limit hardening and small form fixes were applied after that run. The final release compiled successfully. The user explicitly requested no additional test runs, so the latest edits are **not represented as fully re-tested**. No connected Android device was available for the final version.

A prior exact-version OSV check covered 104 remaining hosted Dart packages with no known advisories; root npm audit found none. This does not cover all native/OS/Gradle components or unknown vulnerabilities. Gitleaks history and staged-change scans are part of the push gate. Only the known public Firebase client API key is narrowly allowlisted in its two configuration files; signing credentials are never allowlisted.

## Rollout required before this client can work with production

1. Back up and inventory Auth, Firestore, existing deployed functions, and Storage. Old rules have known vulnerabilities. Do not replace production permissions blindly or delete legacy data automatically.
2. Choose an explicitly reviewed administrator UID. Do not trust historical client-writable role/status/assignments. Build reviewed access decisions for all real users; newly registered users stay pending until approved.
3. Match `security/contract.md` exactly: access + users + employeeDirectory + userProfiles, normalized unique phoneClaims, and timestamp cutoff. This contract uses a Timestamp cutoff, not the earlier experimental numeric-seconds contract. Preserve account UIDs and original historical data separately.
4. Migrate old journal records to version=1/historyId=''/deleted=false, validate house/equipment/operator references and legacy notification recipients. Invalid/empty references must be reviewed. Do not label historical client-authored audit as trustworthy.
5. Validate on Firebase Emulator Suite / staging: `npm ci --ignore-scripts`, Java 21 and Node 24, `npm run test:security`. Run Flutter tests and a real Android release smoke test. `firebase.json` never deploys Cloud Functions.
6. In an authorized maintenance window publish `firestore.rules` and `firestore.indexes.json` only after migration; separately review Storage deny-all impact before publishing `storage.rules`. Remove/disable old plaintext reset and shared-topic push triggers through a separately authorized operation if they exist.
7. Register the actual signing certificate with Firebase/API restrictions. Spark does not require App Check SDK in this client; do not enforce App Check on it without implementing and testing attestation. Client registration is still restricted by Auth and Rules; never use public allow-all Rules.
8. Approve pending users using an established trusted admin; assign their boilerhouses. This code does not silently promote the first registrant.

**Pending users cannot enter protected sections. Until a trusted administrator and the matching deployed rules exist, registration/approval will not be end-to-end operational.** The release artifact alone does not fix a live Firebase project.

## Remaining limitations

- Rules-only Spark cannot atomically revoke Firebase Auth refresh tokens or detect arbitrary Auth Console deletion/disabled state on every Firestore request. For immediate blocking set trusted access status/cutoff through the approved administrative process.
- Phone claims enforce uniqueness for migrated/new profiles but do not verify ownership; number squatting/registration abuse requires quotas, monitoring or verified-phone design.
- Member permissions are enforced per document. Assignment existence is checked client-side by admin service; Rules enforce up to 30 distinct typed IDs, not 30 existence reads. Unknown assignments are a data-quality issue and must be reviewed.
- Reference deletions may leave historical references. Journal evidence is immutable; administrative business deletion must be used carefully. There is no universal audit transaction for every business mutation.
- No background push, private photo/document upload, or in-app administrative password reset. Those need a trusted backend/private-storage design; do not restore the plaintext queue.
- Public source history can still contain earlier operational infrastructure data. Removing APK bundling does not retract copies. No history rewrite was authorized.
- Android is configured; other platform Firebase options/SDK registrations need separate provisioning and release validation. Responsive tests are not a promise that all devices/platforms are supported.

## Build and signing

On Windows without desktop symlink privileges, use process-scoped flags (not global settings):

```sh
FLUTTER_WINDOWS=false FLUTTER_LINUX=false flutter pub get --enforce-lockfile
FLUTTER_WINDOWS=false FLUTTER_LINUX=false flutter build apk --release --obfuscate --split-debug-info=build/symbols/1.2.0
```

Do not continue after failed dependency/platform generation with `--no-pub`. Keep keystore, `android/key.properties`, passwords and symbol maps in a private backup outside Git. Never attach them to a GitHub issue or release. CI only builds explicitly labelled test/debug APKs without release credentials.
