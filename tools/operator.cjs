#!/usr/bin/env node
'use strict';

// Deliberately independent of Flutter, firebase-tools credentials and legacy .tools scripts.
// Admin SDK bypasses Rules: every write below must be justified by explicit reviewed input.
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const { createHash, randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const SDK_VERSION = '14.5.0';
const MAX_INVENTORY = 1000;
const MAX_RECIPIENTS = 100;
const USER_FIELDS = ['id', 'login', 'firstName', 'lastName', 'phone', 'position', 'photoUrl', 'role', 'status', 'boilerhouseIds', 'sessionValidAfter', 'createdAt'];
const ACCESS_FIELDS = ['role', 'status', 'boilerhouseIds', 'sessionValidAfter'];
const PROFILE_FIELDS = ['id', 'firstName', 'lastName', 'position', 'photoUrl', 'role', 'status'];
const NOTIFICATION_FIELDS = ['recipientId', 'senderId', 'type', 'title', 'message', 'isRead', 'createdAt', 'sentAt'];
const JOURNAL_FIELDS = ['boilerHouseId', 'equipmentId', 'eventDateTime', 'category', 'title', 'description', 'importance', 'status', 'authorId', 'authorName', 'createdAt', 'updatedAt', 'version', 'historyId', 'deleted'];
const REPORT_COLLECTIONS = ['journal', 'notifications', 'users', 'access', 'employeeDirectory', 'userProfiles', 'phoneClaims'];
const ROLES = ['admin', 'coAdmin', 'member'];
const STATUSES = ['active', 'pending', 'blocked'];
const TYPES = ['informational', 'important', 'emergency'];

class OperatorError extends Error {
  constructor(code, message) { super(message); this.name = 'OperatorError'; this.code = code; }
}
function requireThat(condition, code, message) {
  if (!condition) throw new OperatorError(code, message);
}
function record(value) { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function exact(value, fields) {
  return record(value) && Object.keys(value).length === fields.length && fields.every(key => Object.hasOwn(value, key));
}
function text(value, max, filled = false) {
  return typeof value === 'string' && value.length <= max && (!filled || value.trim().length > 0) && !/[\u0000-\u001f\u007f]/u.test(value);
}
function docId(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_.-]{1,128}$/u.test(value) && value !== '.' && value !== '..' && !/^__.*__$/u.test(value);
}
function uid(value) { return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/u.test(value); }
function login(value) { return typeof value === 'string' && /^[a-z0-9._-]{3,40}$/u.test(value); }
function phone(value) { return typeof value === 'string' && /^\+[1-9][0-9]{8,14}$/u.test(value); }
function assignments(value) {
  return Array.isArray(value) && value.length <= 30 && new Set(value).size === value.length && value.every(id => typeof id === 'string' && /^[A-Za-z0-9_-]{1,128}$/u.test(id));
}
function normalizeLegacyPhone(value) {
  if (typeof value !== 'string') return null;
  let normalized = value.replace(/[\s()-]/gu, '');
  if (/^[0-9]{9}$/u.test(normalized)) normalized = `+998${normalized}`;
  else if (/^998[0-9]{9}$/u.test(normalized)) normalized = `+${normalized}`;
  return phone(normalized) ? normalized : null;
}
function timestamp(value, Timestamp) {
  return value instanceof Timestamp && Number.isInteger(value.seconds) && Number.isInteger(value.nanoseconds) &&
    value.seconds >= -62135596800 && value.seconds <= 253402300799 && value.nanoseconds >= 0 && value.nanoseconds < 1e9;
}
function parseTimestamp(value, Timestamp) {
  const match = typeof value === 'string' && /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$/u.exec(value);
  requireThat(match, 'TIMESTAMP_ARGUMENT', 'Use an explicit UTC ISO timestamp (up to nine fractional digits), not now or numeric seconds.');
  const millis = Date.parse(`${match[1]}.000Z`);
  requireThat(Number.isFinite(millis) && new Date(millis).toISOString() === `${match[1]}.000Z`, 'TIMESTAMP_ARGUMENT', 'The UTC timestamp is invalid.');
  return new Timestamp(millis / 1000, Number((match[2] || '').padEnd(9, '0')));
}
function projectId(value) { return typeof value === 'string' && /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/u.test(value); }
function pick(value, fields) { return Object.fromEntries(fields.map(key => [key, value[key]])); }

// Explicit tagged encoding preserves Firestore Timestamp nanoseconds in private backups.
function encode(value, Timestamp) {
  if (timestamp(value, Timestamp)) return { $timestamp: { seconds: value.seconds, nanoseconds: value.nanoseconds } };
  if (value === undefined) return { $undefined: true };
  if (Buffer.isBuffer(value)) return { $bytes: value.toString('base64') };
  if (value instanceof Date) return { $date: value.toISOString() };
  if (Array.isArray(value)) return value.map(item => encode(item, Timestamp));
  if (record(value)) return Object.fromEntries(Object.keys(value).sort().map(key => [key, encode(value[key], Timestamp)]));
  return value;
}
function equivalent(a, b, Timestamp) { return JSON.stringify(encode(a, Timestamp)) === JSON.stringify(encode(b, Timestamp)); }
function digest(value, Timestamp) { return createHash('sha256').update(JSON.stringify(encode(value, Timestamp))).digest('hex'); }
function validateAccess(value, Timestamp) {
  requireThat(exact(value, ACCESS_FIELDS) && ROLES.includes(value.role) && STATUSES.includes(value.status) && assignments(value.boilerhouseIds) && timestamp(value.sessionValidAfter, Timestamp),
    'ACCESS_SCHEMA', 'An access record violates the exact Timestamp-based schema; review it separately.');
}
function validateProfile(value, id) {
  requireThat(exact(value, PROFILE_FIELDS) && value.id === id && uid(id) && text(value.firstName, 80, true) && text(value.lastName, 80, true) && text(value.position, 120) && value.photoUrl === '' && ROLES.includes(value.role) && STATUSES.includes(value.status),
    'PROFILE_SCHEMA', 'A public profile violates the exact sanitized profile schema.');
}
function validateUser(value, id, Timestamp) {
  requireThat(exact(value, USER_FIELDS) && value.id === id && login(value.login) && phone(value.phone) && timestamp(value.createdAt, Timestamp),
    'USER_SCHEMA', 'A user/directory record violates the exact schema; legacy or unknown fields require separate review.');
  validateProfile(pick(value, PROFILE_FIELDS), id);
  validateAccess(pick(value, ACCESS_FIELDS), Timestamp);
}
function validateClaim(value, Timestamp) {
  requireThat(exact(value, ['uid', 'createdAt']) && uid(value.uid) && timestamp(value.createdAt, Timestamp),
    'PHONE_CLAIM_SCHEMA', 'A phone claim is malformed; do not overwrite it.');
}
function validateReviewedProfile(value) {
  requireThat(exact(value, ['login', 'firstName', 'lastName', 'phone', 'position']) && login(value.login) && text(value.firstName, 80, true) && text(value.lastName, 80, true) && phone(value.phone) && text(value.position, 120),
    'REVIEWED_PROFILE', 'Profile JSON must contain only login, firstName, lastName, canonical E.164 phone and position. No authority fields.');
}
function validateIdentity(value, expected = {}) {
  requireThat(record(value) && uid(value.uid) && value.disabled === false && !value.tenantId && typeof value.email === 'string' && /^[a-z0-9._-]{3,40}@khorazm-issiklik\.app$/u.test(value.email),
    'AUTH_IDENTITY', 'Use an enabled existing non-tenant app Auth identity with its exact login email.');
  requireThat((!expected.uid || value.uid === expected.uid) && (!expected.email || value.email === expected.email) && (!expected.login || value.email === `${expected.login}@khorazm-issiklik.app`),
    'AUTH_IDENTITY_MISMATCH', 'The selected Auth identity does not exactly match the reviewed profile/selector.');
  requireThat(Array.isArray(value.providerData) && value.providerData.some(provider => provider.providerId === 'password' && provider.email === value.email) &&
    Number.isFinite(Date.parse(value.metadata?.creationTime)) && Number.isFinite(Date.parse(value.metadata?.lastSignInTime)),
    'AUTH_IDENTITY', 'The existing password identity must have a recorded sign-in and valid creation time. No Auth accounts are created by this tool.');
  // Never serialize UserRecord wholesale: it can include password hashes and custom claims.
  return { uid: value.uid, email: value.email, disabled: value.disabled, creationTime: value.metadata.creationTime, lastSignInTime: value.metadata.lastSignInTime };
}

const HELP = `Spark operator (root firebase-admin ${SDK_VERSION}; ADC only)

Commands (dry-run by default)
  provision-admin       Promote one reviewed existing Auth identity or fill missing mirrors.
  migrate-notifications Write a PRIVATE PLAN ONLY; --apply is always refused.
  schema-report         Read-only bounded schema report; no repair or migration.

Required for every command
  --project PROJECT_ID
  --environment production|emulator
  --private-dir ABSOLUTE_EXISTING_PRIVATE_DIRECTORY

provision-admin also requires
  --uid EXACT_UID | --email EXACT_LOGIN_EMAIL     (exactly one)
  --profile ABSOLUTE_PRIVATE_JSON_FILE
  --role admin --status active
  --boilerhouse-ids '[]'                          (explicit JSON, max 30)
  --session-valid-after 1970-01-01T00:00:00.000Z   (example only; review cutoff)
  [--dry-run] | [--apply --confirm-project EXACT_PROJECT_ID]

  Profile JSON: {"login":"...","firstName":"...","lastName":"...","phone":"+...","position":""}
  Existing identity details, assignments and Timestamp cutoff must match exactly.
  Blocked accounts, conflicting mirrors and changed existing admin grants are refused.
  Auth-only profiles use Auth creation time; existing createdAt is preserved.
  Atomic users/access/employeeDirectory/userProfiles/phoneClaims; no Auth mutation.
  Private durable before-images and plan are written BEFORE any transaction writes.

migrate-notifications also requires
  --mapping ABSOLUTE_PRIVATE_JSON_FILE
  Mapping: {"version":1,"projectId":"...","entries":[{"legacyId":"...",
    "senderId":"...","type":"important","recipients":[{"uid":"...","isRead":false}]}]}
  Each recipient and read flag is explicit; no empty audience, wildcard or enumeration.
  At most 100 sources and 100 total recipient documents. Original Timestamp dates
  are required and preserved; provenance stays only in the private plan, not Firestore.

schema-report options
  --collection journal|notifications|users|access|employeeDirectory|userProfiles|phoneClaims
  [--limit 200] [--export]
  Limit 1..1000. Exports are private, credential-like fields redacted. Missing journal
  dates are warnings, never replaced with the current time. Not a full database backup.

Safety
  Emulator mode requires a demo-* project and BOTH local Auth/Firestore host variables.
  Production mode refuses demo-* projects and ANY emulator host. Ambient project IDs
  must agree. No credentials, passwords, tokens, identity data or raw SDK errors stdout.
  Prepare the private directory outside ALL Git worktrees (including this repository).
  POSIX: owner-only 0700 directory/0600 inputs. Windows: protected owner-only ACL
  (SYSTEM and Administrators allowed), owned by the current user. No symlinks/junctions.
  Inputs must be inside that directory. Never publish the plan/backup/export files.
  Dry-run still performs remote reads and local private writes; it consumes quotas.
  --help performs no SDK initialization and no remote access.
`;

function parseArgs(argv) {
  if (argv.length === 0 || argv.includes('--help') || argv[0] === 'help') return { help: true };
  const command = argv[0];
  const common = ['project', 'environment', 'private-dir', 'dry-run'];
  const specifics = {
    'provision-admin': ['uid', 'email', 'profile', 'role', 'status', 'boilerhouse-ids', 'session-valid-after', 'apply', 'confirm-project'],
    'migrate-notifications': ['mapping'],
    'schema-report': ['collection', 'limit', 'export'],
  };
  requireThat(Object.hasOwn(specifics, command), 'ARGUMENTS', 'Unknown command; run --help.');
  const allowed = new Set([...common, ...specifics[command]]);
  const booleans = new Set(['dry-run', 'apply', 'export']);
  const options = { command };
  for (let index = 1; index < argv.length; index++) {
    const key = argv[index].startsWith('--') ? argv[index].slice(2) : '';
    requireThat(allowed.has(key) && !Object.hasOwn(options, key), 'ARGUMENTS', 'Unknown, duplicate or unsupported argument; run --help.');
    if (booleans.has(key)) options[key] = true;
    else {
      const value = argv[++index];
      requireThat(typeof value === 'string' && !value.startsWith('--') && value.length > 0, 'ARGUMENTS', 'An argument value is missing.');
      options[key] = value;
    }
  }
  requireThat(projectId(options.project) && ['production', 'emulator'].includes(options.environment) && typeof options['private-dir'] === 'string',
    'ARGUMENTS', 'An explicit project, environment and private directory are required.');
  requireThat(!(options.apply && options['dry-run']) && (!options['confirm-project'] || options.apply) && (!options.apply || options['confirm-project'] === options.project),
    'CONFIRMATION', 'Writes require --apply and --confirm-project exactly matching --project; dry-run cannot apply.');
  if (command === 'provision-admin') {
    requireThat(Boolean(options.uid) !== Boolean(options.email), 'IDENTITY_SELECTOR', 'Specify exactly one --uid or exact --email; never first-user selection.');
    requireThat((!options.uid || uid(options.uid)) && (!options.email || /^[a-z0-9._-]{3,40}@khorazm-issiklik\.app$/u.test(options.email)), 'IDENTITY_SELECTOR', 'The exact identity selector is invalid.');
    requireThat(options.role === 'admin' && options.status === 'active' && options.profile && options['session-valid-after'] && options['boilerhouse-ids'],
      'REVIEWED_AUTHORITY', 'Explicit --role admin, --status active, profile, assignments and Timestamp cutoff are required.');
    try { options.boilerhouseIds = JSON.parse(options['boilerhouse-ids']); } catch { throw new OperatorError('ASSIGNMENTS', 'Assignments must be an explicit JSON array.'); }
    requireThat(assignments(options.boilerhouseIds), 'ASSIGNMENTS', 'Use at most 30 distinct valid boilerhouse IDs.');
  }
  if (command === 'migrate-notifications') requireThat(options.mapping, 'MAPPING', 'An explicit private recipient mapping is required.');
  if (command === 'schema-report') {
    requireThat(REPORT_COLLECTIONS.includes(options.collection), 'COLLECTION', 'Select one supported report collection; run --help.');
    requireThat(options.limit === undefined || /^[1-9][0-9]{0,3}$/u.test(options.limit), 'LIMIT', 'Report limit must be an integer from 1 through 1000.');
    options.limit = options.limit === undefined ? 200 : Number(options.limit);
    requireThat(options.limit <= 1000, 'LIMIT', 'Report limit cannot exceed 1000.');
  }
  return options;
}
function safeEmulatorHost(value) {
  const match = typeof value === 'string' && /^(127\.0\.0\.1|localhost|\[::1\]):([1-9][0-9]{0,4})$/u.exec(value);
  return Boolean(match && Number(match[2]) <= 65535);
}
function validateEnvironment(options, env) {
  const emulatorKeys = Object.keys(env).filter(key => /EMULATOR.*HOST|HOST.*EMULATOR/u.test(key) && env[key]);
  const known = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'STORAGE_EMULATOR_HOST', 'PUBSUB_EMULATOR_HOST'];
  requireThat(env.NODE_TLS_REJECT_UNAUTHORIZED !== '0', 'UNSAFE_ENVIRONMENT', 'TLS verification must not be disabled.');
  for (const name of ['GOOGLE_CLOUD_PROJECT', 'GCLOUD_PROJECT', 'GCP_PROJECT']) {
    requireThat(!env[name] || env[name] === options.project, 'PROJECT_MISMATCH', 'An ambient project ID differs from --project; clear or correct it.');
  }
  if (env.FIREBASE_CONFIG) {
    let config;
    try { config = JSON.parse(env.FIREBASE_CONFIG); } catch { throw new OperatorError('PROJECT_MISMATCH', 'FIREBASE_CONFIG must not supply a file or implicit project.'); }
    requireThat(record(config) && config.projectId === options.project && !config.databaseURL && !config.credential, 'PROJECT_MISMATCH', 'FIREBASE_CONFIG conflicts with the explicit project.');
  }
  if (options.environment === 'emulator') {
    requireThat(options.project.startsWith('demo-') && safeEmulatorHost(env.FIREBASE_AUTH_EMULATOR_HOST) && safeEmulatorHost(env.FIRESTORE_EMULATOR_HOST),
      'EMULATOR_CONFIGURATION', 'Emulators require a demo-* project and BOTH loopback Auth and Firestore hosts.');
    requireThat(emulatorKeys.every(key => known.includes(key) && safeEmulatorHost(env[key])), 'UNSAFE_EMULATOR_HOST', 'Only recognized loopback emulator host:port values are allowed.');
  } else {
    requireThat(!options.project.startsWith('demo-') && emulatorKeys.length === 0, 'PRODUCTION_CONFIGURATION', 'Production requires a non-demo explicit project and no emulator host variables.');
  }
}

function isWithin(parent, child) {
  const relative = path.relative(parent, child);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}
function rejectLinkedPath(file) {
  let current = file;
  while (true) {
    requireThat(!fs.lstatSync(current).isSymbolicLink(), 'PRIVATE_PATH', 'Private paths must not traverse symlinks or junctions.');
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
}
function rejectGitDirectory(directory) {
  requireThat(!isWithin(fs.realpathSync(ROOT), directory), 'PRIVATE_PATH', 'Private artifacts must be outside the application repository, even ignored directories.');
  let current = directory;
  while (true) {
    const isBare = fs.existsSync(path.join(current, 'HEAD')) && fs.existsSync(path.join(current, 'objects')) && fs.existsSync(path.join(current, 'refs'));
    requireThat(!fs.existsSync(path.join(current, '.git')) && !isBare, 'PRIVATE_PATH', 'Private artifacts must be outside every Git worktree/repository.');
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
}
function checkPermissions(file, stat, directory) {
  if (process.platform !== 'win32') {
    requireThat(stat.uid === process.getuid() && (stat.mode & 0o077) === 0, 'PRIVATE_PERMISSIONS', 'Private directory/inputs must be owned by this user with no group/other permissions (0700/0600).');
    return;
  }
  const script = `$ErrorActionPreference='Stop'; $acl=Get-Acl -LiteralPath $env:ISSIQLIK_OPERATOR_PRIVATE_PATH; ` +
    `$entries=@($acl.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier]) | ForEach-Object { @{sid=$_.IdentityReference.Value; allow=($_.AccessControlType -eq 'Allow')} }); ` +
    `@{current=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value; owner=$acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value; protected=$acl.AreAccessRulesProtected; entries=$entries} | ConvertTo-Json -Compress -Depth 4`;
  let acl;
  try {
    acl = JSON.parse(execFileSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script], {
      env: { ...process.env, ISSIQLIK_OPERATOR_PRIVATE_PATH: file }, encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000, maxBuffer: 65536,
    }));
  } catch { throw new OperatorError('PRIVATE_PERMISSIONS', 'Unable to verify private Windows ACL; no remote operation is allowed.'); }
  requireThat(acl.owner === acl.current && (!directory || acl.protected === true) && Array.isArray(acl.entries) && acl.entries.length > 0 &&
    acl.entries.every(entry => !entry.allow || [acl.current, 'S-1-5-18', 'S-1-5-32-544'].includes(entry.sid)),
    'PRIVATE_PERMISSIONS', 'Use a protected Windows directory ACL owned by this user; only owner, SYSTEM and Administrators may be allowed.');
}
class PrivateStore {
  constructor(directory) {
    requireThat(path.isAbsolute(directory), 'PRIVATE_PATH', 'The private directory must be an explicit absolute path.');
    rejectLinkedPath(directory);
    this.directory = fs.realpathSync(directory);
    rejectGitDirectory(this.directory);
    this.stat = fs.lstatSync(this.directory);
    requireThat(this.stat.isDirectory(), 'PRIVATE_PATH', 'Create the private directory with restricted permissions first.');
    checkPermissions(this.directory, this.stat, true);
  }
  verify() {
    rejectLinkedPath(this.directory);
    rejectGitDirectory(this.directory);
    const current = fs.lstatSync(this.directory);
    requireThat(current.isDirectory() && current.dev === this.stat.dev && current.ino === this.stat.ino, 'PRIVATE_PATH', 'The private directory changed during the operation.');
    checkPermissions(this.directory, current, true);
  }
  readJson(file) {
    this.verify();
    requireThat(path.isAbsolute(file), 'PRIVATE_INPUT', 'Input files must have an absolute path inside the private directory.');
    rejectLinkedPath(file);
    const resolved = fs.realpathSync(file);
    requireThat(isWithin(this.directory, resolved) && resolved !== this.directory, 'PRIVATE_INPUT', 'Input files must be inside the verified private directory.');
    const stat = fs.lstatSync(resolved);
    requireThat(stat.isFile() && stat.nlink === 1 && stat.size <= 1048576, 'PRIVATE_INPUT', 'Private input must be a regular unlinked file of at most 1 MiB.');
    checkPermissions(resolved, stat, false);
    try { return JSON.parse(fs.readFileSync(resolved, 'utf8')); }
    catch { throw new OperatorError('PRIVATE_INPUT', 'Private input is not valid JSON.'); }
  }
  writeArtifact(name, data, Timestamp) {
    this.verify();
    requireThat(/^[a-z0-9-]+\.(backup|plan|receipt|report)\.json$/u.test(name), 'PRIVATE_OUTPUT', 'Invalid private artifact name.');
    const body = `${JSON.stringify(encode(data, Timestamp), null, 2)}\n`;
    requireThat(Buffer.byteLength(body) <= 32 * 1024 * 1024, 'PRIVATE_OUTPUT', 'Private artifact exceeds 32 MiB; reduce the operation scope.');
    const file = path.join(this.directory, name);
    const flags = fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | (fs.constants.O_NOFOLLOW || 0);
    const fd = fs.openSync(file, flags, 0o600);
    try { fs.writeFileSync(fd, body, 'utf8'); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
    checkPermissions(file, fs.lstatSync(file), false);
    if (process.platform !== 'win32') {
      const directory = fs.openSync(this.directory, fs.constants.O_RDONLY);
      try { fs.fsyncSync(directory); } finally { fs.closeSync(directory); }
    }
    return name;
  }
}

function snapshotRecord(snapshot) {
  return { path: snapshot.ref.path, exists: snapshot.exists, updateTime: snapshot.updateTime || null, data: snapshot.exists ? snapshot.data() : null };
}
async function readAdminState(reader, db, id, input) {
  const collections = ['users', 'access', 'employeeDirectory', 'userProfiles', 'phoneClaims'];
  const refs = collections.map(collection => db.doc(`${collection}/${collection === 'phoneClaims' ? input.profile.phone : id}`));
  const docs = Object.fromEntries((await reader.getAll(...refs)).map((snapshot, index) => [collections[index], snapshotRecord(snapshot)]));
  const scans = {};
  for (const collection of ['users', 'employeeDirectory', 'phoneClaims']) {
    const fields = collection === 'phoneClaims' ? ['uid', 'createdAt'] : ['phone', 'login'];
    const found = await reader.get(db.collection(collection).select(...fields).limit(MAX_INVENTORY + 1));
    requireThat(found.docs.length <= MAX_INVENTORY, 'INVENTORY_LIMIT', 'Phone uniqueness inventory exceeds 1000 documents in one collection; use a separately reviewed migration.');
    scans[collection] = found.docs.map(snapshot => ({ id: snapshot.id, ...snapshotRecord(snapshot) }));
  }
  const houses = input.boilerhouseIds.length ? (await reader.getAll(...input.boilerhouseIds.map(id => db.doc(`boilerhouses/${id}`)))).map(snapshotRecord) : [];
  return { docs, scans, houses };
}

function planAdmin({ identity, input, state, Timestamp, now }) {
  validateReviewedProfile(input.profile);
  const auth = validateIdentity(identity, { uid: input.uid, email: input.email, login: input.profile.login });
  requireThat(input.role === 'admin' && input.status === 'active' && assignments(input.boilerhouseIds) && timestamp(input.sessionValidAfter, Timestamp),
    'REVIEWED_AUTHORITY', 'Only an explicit reviewed admin/active promotion with assignments and Timestamp cutoff is supported.');
  requireThat(input.sessionValidAfter.toMillis() >= 0 && input.sessionValidAfter.toMillis() <= now, 'CUTOFF_RANGE', 'The reviewed cutoff cannot be negative or in the future.');
  const id = auth.uid;
  const present = Object.fromEntries(Object.entries(state.docs).filter(([, snapshot]) => snapshot.exists).map(([key, snapshot]) => [key, snapshot.data]));
  for (const name of ['users', 'employeeDirectory']) if (present[name]) validateUser(present[name], id, Timestamp);
  if (present.access) validateAccess(present.access, Timestamp);
  if (present.userProfiles) validateProfile(present.userProfiles, id);
  if (present.phoneClaims) {
    validateClaim(present.phoneClaims, Timestamp);
    requireThat(present.phoneClaims.uid === id, 'PHONE_CONFLICT', 'The reviewed phone is already claimed by another identity.');
  }
  const base = present.users || present.employeeDirectory;
  if (present.users && present.employeeDirectory) requireThat(equivalent(present.users, present.employeeDirectory, Timestamp), 'MIRROR_CONFLICT', 'Existing private/directory mirrors disagree; refusing to choose a winner.');
  const roles = [];
  for (const name of ['users', 'employeeDirectory', 'access', 'userProfiles']) {
    const old = present[name];
    if (!old) continue;
    roles.push(`${old.role}/${old.status}`);
    requireThat(old.status !== 'blocked' && !(old.role === 'admin' && old.status !== 'active'), 'AUTHORITY_CONFLICT', 'Blocked accounts and inactive admins require a separate reviewed recovery, not promotion.');
    if (name !== 'userProfiles') {
      requireThat(equivalent(old.boilerhouseIds, input.boilerhouseIds, Timestamp) && equivalent(old.sessionValidAfter, input.sessionValidAfter, Timestamp),
        'GRANT_CONFLICT', 'Existing assignments/cutoff must match exactly; this promotion tool never changes them.');
    }
    if (name !== 'access') {
      const expected = { id, firstName: input.profile.firstName, lastName: input.profile.lastName, position: input.profile.position, photoUrl: '' };
      requireThat(equivalent(pick(old, Object.keys(expected)), expected, Timestamp), 'IDENTITY_CONFLICT', 'Existing identity/profile details differ from the reviewed input; not overwritten.');
    }
    if (name === 'users' || name === 'employeeDirectory') {
      requireThat(old.login === input.profile.login && old.phone === input.profile.phone, 'IDENTITY_CONFLICT', 'Existing login/phone differs from the reviewed identity.');
    }
  }
  requireThat(new Set(roles).size <= 1, 'MIRROR_CONFLICT', 'Existing role/status mirrors disagree; refusing to infer authority from legacy fields.');
  for (const name of ['users', 'employeeDirectory']) {
    for (const entry of state.scans[name]) {
      const normalized = normalizeLegacyPhone(entry.data.phone);
      requireThat(normalized !== null, 'PHONE_INVENTORY_INVALID', 'The phone inventory contains unresolvable legacy numbers; review them before provisioning.');
      requireThat(normalized !== input.profile.phone || entry.id === id, 'PHONE_CONFLICT', 'Another profile has the same normalized phone, even if its claim is missing.');
      requireThat(entry.data.login !== input.profile.login || entry.id === id, 'IDENTITY_CONFLICT', 'Another profile has the reviewed login.');
    }
  }
  for (const entry of state.scans.phoneClaims) {
    validateClaim(entry.data, Timestamp);
    requireThat(phone(entry.id), 'PHONE_INVENTORY_INVALID', 'Phone claims must use canonical E.164 document IDs; legacy claims need separate review.');
    requireThat((entry.id !== input.profile.phone || entry.data.uid === id) && (entry.data.uid !== id || entry.id === input.profile.phone),
      'PHONE_CONFLICT', 'A conflicting phone claim exists; claims are never reassigned or deleted.');
  }
  requireThat(state.houses.length === input.boilerhouseIds.length && state.houses.every(snapshot => snapshot.exists && snapshot.data.archived !== true),
    'ASSIGNMENT_REFERENCE', 'Every reviewed assignment must refer to an existing non-archived boilerhouse.');
  const createdAt = base?.createdAt || Timestamp.fromMillis(Date.parse(auth.creationTime));
  requireThat(createdAt.toMillis() <= now, 'USER_SCHEMA', 'Creation time is in the future; review the identity separately.');
  const user = { id, ...input.profile, photoUrl: '', role: input.role, status: input.status, boilerhouseIds: [...input.boilerhouseIds], sessionValidAfter: input.sessionValidAfter, createdAt };
  validateUser(user, id, Timestamp);
  const desired = {
    users: user, access: pick(user, ACCESS_FIELDS), employeeDirectory: user, userProfiles: pick(user, PROFILE_FIELDS),
    phoneClaims: present.phoneClaims || { uid: id, createdAt: Timestamp.fromMillis(now) },
  };
  const writes = Object.entries(desired).filter(([name, data]) => !state.docs[name].exists || !equivalent(state.docs[name].data, data, Timestamp))
    .map(([name, data]) => ({ path: state.docs[name].path, operation: state.docs[name].exists ? 'replace' : 'create', data }));
  return { uid: id, auth, stateDigest: digest(state, Timestamp), writes };
}
async function resolveIdentity(auth, options) {
  return options.uid ? auth.getUser(options.uid) : auth.getUserByEmail(options.email);
}
async function provisionAdmin(options, runtime, profile) {
  const { db, auth, Timestamp, store } = runtime;
  const now = runtime.now ? runtime.now() : Date.now();
  const input = { profile, uid: options.uid, email: options.email, role: options.role, status: options.status, boilerhouseIds: options.boilerhouseIds, sessionValidAfter: parseTimestamp(options['session-valid-after'], Timestamp) };
  validateReviewedProfile(profile);
  const identity = await resolveIdentity(auth, options);
  validateIdentity(identity, { uid: options.uid, email: options.email, login: profile.login });
  const state = await db.runTransaction(tx => readAdminState(tx, db, identity.uid, input), { readOnly: true });
  const plan = planAdmin({ identity, input, state, Timestamp, now });
  const operationId = randomUUID();
  const envelope = { version: 1, command: options.command, projectId: options.project, environment: options.environment, operationId, preparedAt: new Date(now).toISOString() };
  // Only records that could change are backed up; other identity inventories are fingerprinted.
  const files = [store.writeArtifact(`${operationId}.backup.json`, { ...envelope, identity: plan.auth, before: state.docs, inventoryDigest: plan.stateDigest, note: 'Private Firestore before-images, not an Auth credential export. Do not upload to Git.' }, Timestamp)];
  files.push(store.writeArtifact(`${operationId}.plan.json`, { ...envelope, mode: options.apply ? 'apply-requested' : 'dry-run', reviewedAuthority: pick(input, ['role', 'status', 'boilerhouseIds', 'sessionValidAfter']), ...plan }, Timestamp));
  let appliedWrites = 0;
  if (options.apply && plan.writes.length) {
    try {
      await db.runTransaction(async tx => {
        const current = await readAdminState(tx, db, identity.uid, input);
        const currentIdentity = await auth.getUser(identity.uid);
        const rechecked = planAdmin({ identity: currentIdentity, input, state: current, Timestamp, now });
        requireThat(rechecked.stateDigest === plan.stateDigest && equivalent(rechecked.auth, plan.auth, Timestamp) && equivalent(rechecked.writes, plan.writes, Timestamp),
          'STATE_CHANGED', 'State changed since the private backup; no planned writes applied. Review a fresh dry-run.');
        for (const write of rechecked.writes) {
          if (write.operation === 'create') tx.create(db.doc(write.path), write.data);
          else tx.set(db.doc(write.path), write.data);
        }
      }, { maxAttempts: 1 });
      appliedWrites = plan.writes.length;
    } catch (error) {
      if (error instanceof OperatorError) throw error;
      throw new OperatorError('COMMIT_OUTCOME_UNKNOWN', 'Transaction did not return a confirmed result. Preserve the private backup/plan and reconcile with a new dry-run; never retry blindly.');
    }
    try {
      files.push(store.writeArtifact(`${operationId}.receipt.json`, { ...envelope, outcome: 'commit-confirmed', appliedWrites, stateDigest: plan.stateDigest }, Timestamp));
    } catch { throw new OperatorError('POST_COMMIT_LOG_FAILED', 'The transaction succeeded but its private receipt could not be saved. Preserve prepared files and reconcile; do not retry blindly.'); }
  }
  return { command: options.command, mode: options.apply ? 'apply' : 'dry-run', operationId, plannedWrites: plan.writes.length, appliedWrites, unchangedDocuments: 5 - plan.writes.length, files };
}

function validateMapping(mapping, project) {
  requireThat(exact(mapping, ['version', 'projectId', 'entries']) && mapping.version === 1 && mapping.projectId === project && Array.isArray(mapping.entries) && mapping.entries.length > 0 && mapping.entries.length <= MAX_RECIPIENTS,
    'MAPPING', 'Use a version-1 mapping bound to the explicit project with 1..100 reviewed sources.');
  let recipients = 0;
  const sources = new Set();
  for (const entry of mapping.entries) {
    requireThat(exact(entry, ['legacyId', 'senderId', 'type', 'recipients']) && docId(entry.legacyId) && uid(entry.senderId) && TYPES.includes(entry.type) && Array.isArray(entry.recipients) && entry.recipients.length > 0 && !sources.has(entry.legacyId),
      'MAPPING', 'Every source needs a unique exact ID, reviewed sender/type and explicit nonempty recipient list.');
    sources.add(entry.legacyId);
    const targets = new Set();
    for (const recipient of entry.recipients) {
      requireThat(exact(recipient, ['uid', 'isRead']) && uid(recipient.uid) && !['all', 'broadcast'].includes(recipient.uid.toLowerCase()) && typeof recipient.isRead === 'boolean' && !targets.has(recipient.uid),
        'MAPPING', 'Each exact recipient UID and read flag must be reviewed; duplicate/wildcard/broadcast recipients are forbidden.');
      targets.add(recipient.uid);
      recipients++;
    }
  }
  requireThat(recipients <= MAX_RECIPIENTS, 'MAPPING_LIMIT', 'At most 100 recipient documents per private migration plan; no audience enumeration or mass broadcast.');
}
function notificationId(project, source, recipient) {
  return `legacy_${createHash('sha256').update(JSON.stringify([project, source, recipient])).digest('hex')}`;
}
function notificationIssues(data, Timestamp) {
  const issues = [];
  if (!exact(data, NOTIFICATION_FIELDS)) issues.push('notification_exact_fields');
  if (!record(data)) return issues;
  if (!uid(data.recipientId) || !uid(data.senderId)) issues.push('notification_identity');
  if (!TYPES.includes(data.type)) issues.push('notification_type');
  if (!text(data.title, 200, true) || typeof data.message !== 'string' || data.message.trim().length === 0 || data.message.length > 4000) issues.push('notification_content');
  if (typeof data.isRead !== 'boolean') issues.push('notification_read_flag');
  for (const field of ['createdAt', 'sentAt']) if (!timestamp(data[field], Timestamp)) issues.push(`missing_or_invalid_${field}`);
  return issues;
}
function planNotifications({ mapping, sources, targets, identities, access, Timestamp }) {
  validateMapping(mapping, mapping.projectId);
  const proposals = [];
  const provenance = [];
  const issues = [];
  let unchanged = 0;
  for (const entry of mapping.entries) {
    const source = sources[entry.legacyId];
    const blocked = [];
    if (!source?.exists) blocked.push('source_missing');
    const data = source?.data || {};
    for (const field of ['createdAt', 'sentAt']) if (!timestamp(data[field], Timestamp)) blocked.push(`missing_or_invalid_${field}`);
    if (!text(data.title, 200, true) || typeof data.message !== 'string' || data.message.trim().length === 0 || data.message.length > 4000) blocked.push('invalid_source_content');
    for (const id of [entry.senderId, ...entry.recipients.map(recipient => recipient.uid)]) {
      try {
        validateIdentity(identities[id], { uid: id });
        validateAccess(access[id], Timestamp);
        requireThat(access[id].status === 'active', 'MIGRATION_IDENTITY', 'Mapped identity is not active.');
        if (id === entry.senderId) requireThat(['admin', 'coAdmin'].includes(access[id].role), 'MIGRATION_IDENTITY', 'Reviewed sender is not a current manager.');
      } catch { blocked.push('mapped_identity_not_active_or_valid'); }
    }
    const alreadyCurrent = notificationIssues(data, Timestamp).length === 0;
    if (alreadyCurrent && (entry.recipients.length !== 1 || entry.recipients[0].uid !== data.recipientId || entry.recipients[0].isRead !== data.isRead || entry.senderId !== data.senderId || entry.type !== data.type)) blocked.push('current_notification_conflict');
    const pending = [];
    let matching = 0;
    if (blocked.length === 0) {
      if (alreadyCurrent) matching++;
      else for (const recipient of entry.recipients) {
        const id = notificationId(mapping.projectId, entry.legacyId, recipient.uid);
        const proposed = { recipientId: recipient.uid, senderId: entry.senderId, type: entry.type, title: data.title, message: data.message, isRead: recipient.isRead, createdAt: data.createdAt, sentAt: data.sentAt };
        requireThat(notificationIssues(proposed, Timestamp).length === 0, 'NOTIFICATION_SCHEMA', 'Planned target violates the exact per-recipient schema.');
        if (targets[id]?.exists) {
          if (equivalent(targets[id].data, proposed, Timestamp)) matching++;
          else blocked.push('target_conflict');
        } else pending.push({ path: `notifications/${id}`, operation: 'create', data: proposed });
      }
    }
    if (blocked.length) issues.push({ legacySourceId: entry.legacyId, codes: [...new Set(blocked)] });
    else { proposals.push(...pending); unchanged += matching; }
    provenance.push({ legacySourceId: entry.legacyId, sourceUpdateTime: source?.updateTime || null, sourceDigest: digest(data, Timestamp), targetPaths: pending.map(item => item.path), status: blocked.length ? 'blocked' : 'review-required',
      notes: ['No delivery, deletion or Firestore write performed.', 'Sender, type, audience and per-recipient read state are explicit operator decisions, not verified historical facts.'] });
  }
  return { planOnly: true, proposals, provenance, issues, unchanged, blockedSources: issues.length };
}
async function migrationPlan(options, runtime, mapping) {
  const { db, auth, Timestamp, store } = runtime;
  validateMapping(mapping, options.project);
  const ids = [...new Set(mapping.entries.flatMap(entry => [entry.senderId, ...entry.recipients.map(recipient => recipient.uid)]))];
  const identities = {};
  for (const id of ids) {
    try { identities[id] = await auth.getUser(id); }
    catch (error) { if (error.code === 'auth/user-not-found') identities[id] = null; else throw error; }
  }
  const targetIds = mapping.entries.flatMap(entry => entry.recipients.map(recipient => notificationId(options.project, entry.legacyId, recipient.uid)));
  const state = await db.runTransaction(async tx => {
    const sourceDocs = await tx.getAll(...mapping.entries.map(entry => db.doc(`notifications/${entry.legacyId}`)));
    const targetDocs = await tx.getAll(...targetIds.map(id => db.doc(`notifications/${id}`)));
    const accessDocs = await tx.getAll(...ids.map(id => db.doc(`access/${id}`)));
    return {
      sources: Object.fromEntries(sourceDocs.map(snapshot => [snapshot.id, snapshotRecord(snapshot)])),
      targets: Object.fromEntries(targetDocs.map(snapshot => [snapshot.id, snapshotRecord(snapshot)])),
      access: Object.fromEntries(accessDocs.map(snapshot => [snapshot.id, snapshot.exists ? snapshot.data() : null])),
    };
  }, { readOnly: true });
  const plan = planNotifications({ mapping, ...state, identities, Timestamp });
  const operationId = randomUUID();
  const file = store.writeArtifact(`${operationId}.plan.json`, { version: 1, command: options.command, projectId: options.project, environment: options.environment, operationId, mapping, ...plan,
    warning: 'Private review plan only. Source timestamps retained; no legacySourceId field is added to notification documents. A separate reviewed migration must revalidate state before writing.' }, Timestamp);
  return { command: options.command, mode: 'plan-only', operationId, sources: mapping.entries.length, plannedDocuments: plan.proposals.length, unchangedDocuments: plan.unchanged, blockedSources: plan.blockedSources, appliedWrites: 0, files: [file] };
}

function inspectRecord(collection, id, data, Timestamp) {
  const issues = [];
  try {
    if (collection === 'users' || collection === 'employeeDirectory') validateUser(data, id, Timestamp);
    else if (collection === 'access') validateAccess(data, Timestamp);
    else if (collection === 'userProfiles') validateProfile(data, id);
    else if (collection === 'phoneClaims') { validateClaim(data, Timestamp); requireThat(phone(id), 'PHONE_CLAIM_SCHEMA', 'Phone claim path invalid.'); }
    else if (collection === 'notifications') issues.push(...notificationIssues(data, Timestamp));
    else if (collection === 'journal') {
      if (!exact(data, JOURNAL_FIELDS)) issues.push('journal_exact_fields');
      for (const field of ['eventDateTime', 'createdAt', 'updatedAt']) if (!timestamp(data?.[field], Timestamp)) issues.push(`missing_or_invalid_${field}`);
      if (!Number.isInteger(data?.version) || data.version < 1 || !text(data?.historyId, 128) || typeof data?.deleted !== 'boolean') issues.push('journal_history_metadata');
      if (!docId(data?.boilerHouseId) || !(data?.equipmentId === null || docId(data?.equipmentId)) || !uid(data?.authorId)) issues.push('journal_reference_shape');
      if (!text(data?.title, 200, true) || !text(data?.category, 120) || typeof data?.description !== 'string' || data.description.length > 10000 || !text(data?.authorName, 161)) issues.push('journal_content');
      if (!['normal', 'important', 'critical'].includes(data?.importance) || !['open', 'inProgress', 'closed'].includes(data?.status)) issues.push('journal_state');
    }
  } catch (error) { issues.push(error instanceof OperatorError ? error.code : 'invalid_schema'); }
  return issues;
}
function redactCredentialFields(data) {
  if (Array.isArray(data)) return data.map(redactCredentialFields);
  if (!record(data) || Object.getPrototypeOf(data) !== Object.prototype) return data;
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, /password|token|secret|private.?key|credential/iu.test(key) ? '[REDACTED]' : redactCredentialFields(value)]));
}
async function schemaReport(options, runtime) {
  const { db, Timestamp, store } = runtime;
  const result = await db.collection(options.collection).limit(options.limit + 1).get();
  const records = result.docs.slice(0, options.limit).map(snapshot => ({ path: snapshot.ref.path, updateTime: snapshot.updateTime || null,
    issues: inspectRecord(options.collection, snapshot.id, snapshot.data(), Timestamp), ...(options.export ? { data: redactCredentialFields(snapshot.data()) } : {}) }));
  const truncated = result.docs.length > options.limit;
  const operationId = randomUUID();
  const affectedDocuments = records.filter(item => item.issues.length).length;
  const file = store.writeArtifact(`${operationId}.report.json`, { version: 1, command: options.command, projectId: options.project, environment: options.environment, operationId, collection: options.collection, records, truncated,
    limitations: ['Bounded root-collection schema inspection, not a full database/Auth backup.', 'Does not validate linked records, journal history subcollections, deployed Rules, IAM, App Check or API restrictions.', 'Missing dates are not repaired. Credential-like fields are redacted from optional exports.'] }, Timestamp);
  return { command: options.command, mode: 'read-only', operationId, inspectedDocuments: records.length, affectedDocuments, truncated, appliedWrites: 0, files: [file] };
}

function openRuntime(options) {
  const rootRequire = createRequire(path.join(ROOT, 'package.json'));
  requireThat(rootRequire('firebase-admin').SDK_VERSION === SDK_VERSION, 'SDK_VERSION', 'Install the locked root firebase-admin 14.5.0 dependency with npm ci --ignore-scripts.');
  const { initializeApp, applicationDefault, deleteApp } = rootRequire('firebase-admin/app');
  const { getAuth } = rootRequire('firebase-admin/auth');
  const { getFirestore, Timestamp } = rootRequire('firebase-admin/firestore');
  const app = initializeApp({ projectId: options.project, credential: applicationDefault() }, `operator-${randomUUID()}`);
  const db = getFirestore(app);
  return { auth: getAuth(app), db, Timestamp, close: async () => { try { await db.terminate(); } finally { await deleteApp(app); } } };
}
async function runCli(argv, injected = {}) {
  const options = parseArgs(argv);
  if (options.help) return { help: HELP };
  validateEnvironment(options, injected.env || process.env);
  const store = injected.store || new PrivateStore(options['private-dir']);
  const input = options.command === 'provision-admin' ? store.readJson(options.profile) : options.command === 'migrate-notifications' ? store.readJson(options.mapping) : null;
  if (options.command === 'provision-admin') validateReviewedProfile(input);
  if (options.command === 'migrate-notifications') validateMapping(input, options.project);
  const runtime = { ...(await (injected.openRuntime || openRuntime)(options)), store };
  try {
    if (options.command === 'provision-admin') return await provisionAdmin(options, runtime, input);
    if (options.command === 'migrate-notifications') return await migrationPlan(options, runtime, input);
    return await schemaReport(options, runtime);
  } finally { if (runtime.close) await runtime.close(); }
}
function publicError(error) {
  if (error instanceof OperatorError) return { error: error.code, message: error.message };
  if (error?.code === 'auth/user-not-found') return { error: 'AUTH_IDENTITY_NOT_FOUND', message: 'The exact Auth identity was not found. No account is created automatically.' };
  return { error: 'OPERATION_FAILED', message: 'Operation failed. Raw SDK/filesystem details are suppressed to protect credentials and personal data. Preserve private artifacts; for an uncertain apply, reconcile before retrying.' };
}
if (require.main === module) {
  runCli(process.argv.slice(2)).then(result => {
    process.stdout.write(result.help || `${JSON.stringify(result)}\n`);
    if (result.blockedSources || result.affectedDocuments || result.truncated) process.exitCode = 2;
  }).catch(error => { process.stderr.write(`${JSON.stringify(publicError(error))}\n`); process.exitCode = 1; });
}
module.exports = { ROOT, USER_FIELDS, ACCESS_FIELDS, PROFILE_FIELDS, NOTIFICATION_FIELDS, HELP, OperatorError, PrivateStore,
  parseArgs, validateEnvironment, safeEmulatorHost, parseTimestamp, validateReviewedProfile, validateMapping, validateIdentity,
  encode, equivalent, digest, planAdmin, notificationId, planNotifications, inspectRecord, redactCredentialFields, runCli, publicError };
