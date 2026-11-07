# Release 1.2.1 — Liquid Glass and Firebase rollout

## Completed

- Based on the latest H-drive project and its current launcher icon, not the earlier cloned UI.
- Bottom navigation uses one clipped backdrop blur and a painted liquid lens. Lens shape responds to press pressure and travel velocity; spring motion retargets from the current presentation position rather than restarting. Reduced motion, fast taps, route changes, narrow/wide layouts and semantics are covered by focused widget tests.
- Fixed a rules expression-budget issue for 30 boilerhouse assignments without removing type checks or ownership validation. Atomic directory mirrors remain coupled to the authorized private-user mutation.
- Firebase CLI authenticated through the owner's OAuth authorization. No OAuth code/token, signing key, password, production export or APK is committed.
- Production Firestore Rules and indexes deployed to `android-app-63a1c` on 2026-11-07 after a private backup and 24 passing emulator scenarios. Existing functions list was empty. Billing remained Spark; Storage rules were not deployed in this operation.
- Inventory before rollout: users/access/employeeDirectory/userProfiles empty; 97 boilerhouses, 12 drawing records, 3 equipment records, 1 instruction, 4 legacy notifications and 10 legacy audit records. No business documents or Auth accounts were deleted or modified.

## Verification

- `flutter analyze`: no issues.
- Focused bottom-navigation widget tests: 14 passed.
- Firestore/Storage emulator scenario groups: 24 passed before Firestore deployment.
- Optimized release APK built, version 1.2.1 / code 6, same RSA-3072 signing key, debug mode absent, APK signature and 16 KiB zip alignment verified.
- APK SHA256: `24163242854a1d619f922afb25bcd813db0d7247bbfa9e3175c9af9e08cf6c7e`.
- No Android phone was connected for a physical-device end-to-end run. Claims of registration success refer to emulator verification plus successful rules deployment, not an unperformed production signup.

## Still required for full account access

Registration is deliberately **member/pending**. Auth-only accounts from earlier failed attempts can reuse their original login/password to finish registration; active existing registration is not overwritten. A pending user is not allowed into protected business sections.

**The owner has not yet selected the first trusted administrator UID.** No arbitrary account was promoted. The owner must identify the account and approve its authority before normal users can be approved in the app. Rules published here do not make the first registrant an administrator.

Historical business records still need schema/reference review for editing. No bulk migration was performed: a legacy record that violates current schema fails closed rather than being silently rewritten. Background push, new confidential-file uploads and in-app administrator password resets remain unsupported in this Spark variant. See `contract.md` for access/profile schema.

## Distribution

Local APK: `H:/Projects/Issiqlik_Taminoti_1.2.1.apk` (57,506,981 bytes).

AyuGram was observed initially, then exited. It was unavailable through the desktop launcher when delivery was attempted; Saved Messages delivery is not confirmed. Do not claim it was sent.

The prior `README.md`/`security/README.md` statements that no Firestore deployment has occurred are superseded for Rules and indexes by this release note. They remain correct for Storage deployment, business-data migration, account promotion and billing upgrades.

## Addendum — rebuild 1.2.1 (code 7) after the audit remediation (2026-11-07)

Follow-up build with the audit-fix set: archive-with-history instead of hard deletes, classified sign-in/registration failures, legacy-doc-tolerant streams with per-document skip and data-quality banner, persisted language/dark mode, dark theme wiring, documented `tools/operator.cjs` provisioning, dead dependencies/seeds/schematics removed, Gitleaks job enforced in CI, single-read boilerhouse reference validation instead of serial round-trips, and no unbounded re-read loops. README build steps target `1.2.1` again (`code 7` supersedes `code 6`).

Verification: `flutter analyze` clean (0 issues), all 50 Dart widget/service tests pass, operator suite green, release APK signed with the same RSA-3072 key.

APK: `build/issiqlik-taminoti-v1.2.1-7-release.apk` (58.0 MB), versionName 1.2.1 / versionCode 7.
APK SHA256: `3F6EF28CD471A03097C7C369C7E92ADADB65303C06EC56183638F154162B2818`.

The first-admin bootstrap requirement is unchanged: use `tools/operator.cjs` (documented in `security/README.md`) — registration still always creates `member/pending`.
