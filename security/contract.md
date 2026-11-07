# Spark security API / rules contract

Implementation target: H:/Projects/androidSdkProj. No Blaze, Functions dependency, deployment, or automatic first-admin selection.

## UI integration

Existing `FirebaseService` mutation names stay available and return awaited `Future`s. Provider action wrappers now return `Future<void>`; screens must await them and surface errors. `approveUser`, `declineUser`, `banUser`, `unbanUser`, `changeRole`, `updateUserPosition` remain functional for an active **admin**. Add `assignBoilerhouses(String uid, List<String> ids)` for assignments (maximum 30 distinct existing houses). Self-management of privilege/status and any modification of an admin's authority are forbidden. `changeRole(..., UserRole.admin)` is operator-only and throws an actionable unsupported error. An existing admin can grant/revoke coAdmin. coAdmin may manage business records, not user authority.

`currentUserProvider` must only contain a server-validated active user; restore/login and live synchronization fail closed on missing/blocked/pending/revoked access or network validation error. Router/UI should clear protected screens when it becomes null. All feature providers pass the current user into scoped service reads. Members see assigned boilerhouses and their equipment/journal/drawings/shifts. Empty assignments produce empty streams without a Firestore query. Instructions and sanitized active colleague names are available to active users. Managers see `employeeDirectory` (including login/phone); other members receive sanitized `userProfiles` mapped to `AppUser` with blank login/phone. `users` cannot be listed or read by another client.

Registration creates own `users`, `access`, `employeeDirectory`, `userProfiles`, and unique `phoneClaims` atomically. Every registration is member/pending with zero assignments. There is no first-user privilege. A reviewed external Admin SDK script must provision/migrate trusted authority (main agent owns tooling); do not infer admin from old users fields or select an arbitrary UID.

Journal creation stamps trusted author/name/server times. Updates preserve author, creation/event time and boilerhouse, and atomically append immutable `journal/{id}/history/{historyId}` with the exact previous record. Delete means an audited tombstone, not physical removal; existing UI delete method remains available. `changeLogs` and their reactions are append-only; removing them is unsupported to preserve history. No client-written audit log should be represented as server-authoritative evidence.

Notifications remain functional **in app**. One `notifications` document per exact `recipientId`, recipient-only read flag. Only active managers send informational/important/emergency notifications, never `system`. `broadcastNotification` resolves active recipients explicitly, maximum 100 per operation, committed in small batches; it is not a topic or unauthenticated broadcast. Add `sendNotification({required title, required message, required List<String> recipientIds})` for bounded explicit sends. No FCM delivery is available on the selected serverless Spark implementation. Old device topic/token registration is disabled/cleaned up best-effort; do not promise background push.

## Explicitly unsupported operations

`adminResetPassword` throws `UnsupportedError` with operator recovery guidance and never writes a password anywhere. `requestPasswordReset` returns an actionable non-null error (synthetic emails cannot receive reset links; contact administrator for identity-verified operator recovery). Own `changePassword` works through Auth reauthentication. `deleteAccount` returns an actionable non-null operator-assisted deprovisioning message; preserve operational attribution and phone claim uniqueness. `uploadFile(s)` and `updateUserPhoto` throw unsupported errors; keep current upload UI disabled. No fabricated upload URLs, bearer download URLs, local file paths or arbitrary external drawing paths are accepted. Drawing metadata may use an empty file path or an approved bundled `assets/schemas/...` image only. Storage remains deny-all until an authenticated private-file workflow is designed.

## Migration / deployment gate

Existing schema lacks trusted access, directory mirrors and journal version/history metadata. Do not deploy these rules against unmigrated live data. Reviewed, backed-up operator migration must establish access (only from explicitly reviewed authority/assignments), exact private/directory mirrors, normalized unique phone claims, sanitized bundled drawing paths and valid business schemas, journal version=1/historyId=''/deleted=false. Remove legacy notification documents, plaintext password reset documents and obsolete FCM tokens only through reviewed operator work. Existing deployed legacy Functions must be explicitly disabled/removed by an operator; changing source alone does not remove deployed triggers. Nothing in this task performs production operations.

## Rules fixture schema

`access/{uid}` exact fields: `role` (`admin|coAdmin|member`), `status` (`active|pending|blocked`), `boilerhouseIds` (unique list, max 30), `sessionValidAfter` (Timestamp). Requests require active access and Auth `auth_time*1000 >= sessionValidAfter.toMillis()`.

`users/{uid}` and `employeeDirectory/{uid}` exact fields: `id, login, firstName, lastName, phone, position, photoUrl, role, status, boilerhouseIds, sessionValidAfter, createdAt`. `photoUrl` is empty. `userProfiles/{uid}` exact fields: `id, firstName, lastName, position, photoUrl, role, status`. Mirrors and access must agree in the same atomic operation. `phoneClaims/{normalizedPhone}` exact fields: `uid, createdAt`; clients can create once only as part of their registration; no reads/updates/deletes.

Further executable schema details and positive/negative examples live in firestore.rules and security-tests/firebase.test.cjs.
