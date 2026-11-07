# Security and reliability — current 1.2.1 contract

The latest owner-provided H-drive project and Liquid Glass navigation are preserved. The owner previously selected and activated an administrator manually; no real identity or bootstrap privilege is embedded in this repository. Registration remains member/pending. Use the reproducible [operator CLI](OPERATOR.md) for a reviewed new environment or missing mirrors.

## Audit findings addressed

| Area | Implementation |
|---|---|
| Login diagnostics | Typed `SignInResult`/`AuthFailure` distinguish invalid credentials, pending, blocked/revoked sessions, missing/malformed profile, permission denial, rate limits and network errors. Protected providers receive only verified active users. |
| Registration cleanup | Awaited, handled cleanup cannot turn a confirmed registration into a false registration failure. Cleanup trouble is reported separately; ambiguous writes are never rolled back by deleting Auth. |
| Legacy values | Pure document codec validates every displayed row; an invalid row is skipped with a counts-only warning. Authority/profile parsing is strict and never grants default permissions. Legacy broadcasts without recipientId are not auto-exposed. |
| Async operations | Assignment validation uses one document-ID query; message batches have bounded parallelism and explicit failed/uncertain outcomes. Mark-all snapshots at most 1000 records and terminates; new arrivals cannot extend it indefinitely. |
| Sync errors | The returned write future owns error propagation; later successful writes recover error state. Generation tracking prevents old writes corrupting a reset session's counters. |
| IDs and overwrites | Firestore auto IDs allocated once per create intent. Create transactions reject an existing target rather than treating retry as overwrite. |
| Destructive operations | No client physical deletes for business entities. Only admin can archive; each archive atomically stores actor/time and exact before-image at `history/archive`. Archived objects cannot be edited/unarchived by the client. |
| Settings/UI | SharedPreferences stores appearance only; language and theme persist without overwriting a newer user choice. Dark theme is connected. Localization arguments are typed; admin screen split into focused parts and controllers disposed. |
| CI | Required Gitleaks job checks full fetched history and sources with an official pinned binary/checksum. Exact public Firebase key allowed only for its two client config files; no private keys/tokens allowed. |
| Tooling/docs | ADC-only operator CLI, dry-run default, explicit identity/project/authority, pre-write private backups and conflict refusal. README translations describe Spark, not removed Functions. |
| Dead code/dependencies | Unused Storage/local-notification/image-picker packages and disabled upload code removed; FCM is retained only for bounded, unawaited legacy cleanup with auto-init disabled. Historical seeds/schemas removed from current tree after private backup. |

## Important boundaries

- Firestore Rules are the authorization boundary. Client checks, local login delays and UI hiding are not security controls.
- A blocked user's cutoff is preserved on unban. A fresh login is required; resetting the cutoff would revive an old session.
- Rules cannot synchronously read Firebase Auth disabled/revoked status. Use the trusted access status/cutoff for immediate application blocking; broader Auth revocation/deprovisioning remains operator-assisted.
- Phone claims ensure uniqueness among reviewed/new profiles but do not prove phone ownership. Auth quotas, anti-abuse measures and monitoring are still required.
- Up to 30 distinct typed assignments are validated by Rules. The client checks current referenced houses in one query; Rules cannot spend 30 existence reads per mutation. A trusted admin's dangling assignment is a data-quality issue, not an implicit grant to another existing house.
- Readable legacy activity logs are explicitly labelled **client-reported, not independent server audit**, and now read-only. Journal and archive histories are integrity-bound; ordinary edits of all reference entities do not claim universal audited history.
- A timed-out network write may later commit. The app reports uncertainty/partial success and uses stable IDs; it does not silently resend or promise exactly-once delivery.
- No background push, confidential uploads, automatic email recovery to synthetic login emails, or in-app admin password reset in this Spark variant. Storage policy remains deny-all until a private-file workflow is separately designed.
- Firebase client configuration is public, not a service-account secret. The Android release certificate and Play Integrity registration were configured earlier, but this Spark client does not enforce attestation. API-key restrictions and live IAM are not certified by source scanning.
- Removing old seeds/schema files from the current tree does not retract Git history, older APKs or external copies. No history rewrite was performed.
- Android is the configured release target. Other platform Firebase registrations and physical-device validation are separate; responsive tests are not universal device certification.

## Test and deployment commands

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
npm ci --ignore-scripts
npm run test:security
npm run test:operator
npm audit
```

Security tests use a loopback demo project and require Node 24.12+ / Java 21. Operator unit tests inject SDK/storage; they never touch production. POSIX-only permission cases skip on Windows and run in Linux CI. Test results for a release must be read from its actual run, not assumed from this command list.

Before production changes, back up published rules and data, inspect existing authority/mirrors, and verify identity/ref schemas. Archive fields are optional for legacy records; archival adds `archived:true`, `archivedAt:Timestamp`, `archivedBy:uid` plus an immutable receipt. Existing users/access schema and cutoff type are unchanged. No automatic bulk rewrite or guessed migration recipients/dates is permitted.

Publish tested Firestore rules/indexes in a controlled rollout; Storage deny-all requires separate impact review. Existing deployed Functions are not removed merely by deleting local exports. The operator notification command writes a **private migration plan only**; it does not send, delete or apply broadcasts.

## Release hygiene

Build with a private external keystore and ignored `android/key.properties`; no debug fallback. Preserve obfuscation symbols outside Git. Windows without desktop symlink privileges can run `FLUTTER_WINDOWS=false FLUTTER_LINUX=false flutter ...`; never bypass a failed plugin generation step with `--no-pub`.

Gitleaks is enforced in CI and locally before push. Protected credentials, production exports and signing files are excluded from the repository. Security/advisory scan results do not prove absence of unknown bugs or malicious intent; they establish only what was actually checked.
