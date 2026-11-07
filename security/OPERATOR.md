# Trusted operator CLI

`tools/operator.cjs` uses the locked root Firebase Admin SDK **14.5.0** and **Application Default Credentials (ADC)**. It never embeds credentials or account IDs and never creates Auth accounts. `firebase login` alone is not ADC. Set up workload identity / an appropriately restricted ADC principal outside this repository; do not download or commit service-account keys to make the tool work.

```sh
npm ci --ignore-scripts
npm run operator -- --help
npm run test:operator
```

## Private working directory

Create an existing absolute directory outside every Git worktree. On Linux/macOS restrict it to owner-only `0700`, input files to `0600`. On Windows use a protected ACL owned by the current user with access only to that user, SYSTEM and optionally Administrators. The tool verifies permissions, symlinks/junctions, input hardlinks and location before remote calls. Output files contain PII and must stay private; do not attach them to issues or logs.

## Provision an explicitly reviewed administrator

First register the intended account and verify its Auth identity. Prepare a private profile JSON containing only:

```json
{"login":"reviewed-login","firstName":"Reviewed","lastName":"Operator","phone":"+19999999999","position":""}
```

The sample is fictional; use the verified account's exact profile. Role, status, assignments and Timestamp cutoff are explicit CLI arguments, not inferred from legacy fields.

```sh
node tools/operator.cjs provision-admin \
  --project YOUR_PROJECT_ID --environment production \
  --private-dir /absolute/private-dir \
  --uid VERIFIED_AUTH_UID --profile /absolute/private-dir/profile.json \
  --role admin --status active --boilerhouse-ids '[]' \
  --session-valid-after 1970-01-01T00:00:00.000Z --dry-run
```

On Windows use absolute drive paths and shell-appropriate line continuation. The epoch cutoff is an example for a new reviewed identity, not a recommendation to erase an existing revocation. Existing assignments/cutoff/profile details must match. Blocked accounts, conflicting mirrors, phone collisions or changed existing admin grants are refused. Existing `createdAt` is preserved; Auth-only identities use Auth's recorded creation time.

Inspect the private backup and plan. To apply that same reviewed request, replace `--dry-run` with `--apply --confirm-project YOUR_PROJECT_ID`. The tool rechecks state and identity in the transaction; it aborts if the prepared state changed. It writes the exact users/access/employeeDirectory/userProfiles/phoneClaims relationship atomically. No password, Auth disabling, billing or Rules changes are performed.

Do not blindly repeat an uncertain apply. Retain prepared artifacts, run a fresh dry-run and reconcile. Successful no-op is supported for already matching admin state. The currently selected production administrator was previously activated manually by the owner; no real UID is shipped in this guide.

## Legacy notification migration planning

```sh
node tools/operator.cjs migrate-notifications \
  --project YOUR_PROJECT_ID --environment production \
  --private-dir /absolute/private-dir --mapping /absolute/private-dir/mapping.json
```

Mapping schema:

```json
{"version":1,"projectId":"YOUR_PROJECT_ID","entries":[{"legacyId":"SOURCE_DOCUMENT_ID","senderId":"REVIEWED_MANAGER_UID","type":"important","recipients":[{"uid":"REVIEWED_RECIPIENT_UID","isRead":false}]}]}
```

This command writes a **private plan only** and rejects `--apply`. It never infers an audience from an empty legacy broadcast list, enumerates all staff, deletes sources or sends notifications. All mapped identities and the sender's current role are checked. Valid source timestamps are preserved with nanosecond precision; missing dates block the plan rather than becoming today's date. Deterministic target IDs, source digest/updateTime and provenance remain in the private artifact. A reviewed migration must recheck preconditions before writing.

## Bounded schema report

```sh
node tools/operator.cjs schema-report \
  --project YOUR_PROJECT_ID --environment production \
  --private-dir /absolute/private-dir --collection journal --limit 200
```

Supported collections are listed in `--help`. Optional `--export` redacts credential-like fields but still contains PII: keep it private. Reports do not mutate data or inspect all relationships/subcollections; they are not full backups. Exit code 2 means blocked records/truncation require review; exit code 1 is an error, 0 is a clean operation.

## Emulator isolation

`--environment emulator` requires a `demo-*` project and loopback Auth and Firestore emulator hosts. Production refuses emulator hosts or conflicting ambient project settings. Unit tests inject SDK/storage and do not access production. Two POSIX permission tests are skipped on Windows; CI on Linux exercises them.
