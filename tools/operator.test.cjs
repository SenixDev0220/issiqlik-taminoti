'use strict';

// All identities/data are synthetic. Tests inject Auth/Firestore; never load a real credential.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const operator = require('./operator.cjs');

class Timestamp {
  constructor(seconds, nanoseconds = 0) { this.seconds = seconds; this.nanoseconds = nanoseconds; }
  static fromMillis(value) { const seconds = Math.floor(value / 1000); return new Timestamp(seconds, (value - seconds * 1000) * 1e6); }
  toMillis() { return this.seconds * 1000 + this.nanoseconds / 1e6; }
}
const epoch = Timestamp.fromMillis(0);
const created = Timestamp.fromMillis(1700000000000);
const NOW = 1800000000000;
const PROJECT = 'demo-operator-test';
const ID = 'synthetic-admin';
const PROFILE = { login: 'synthetic.admin', firstName: 'Synthetic', lastName: 'Operator', phone: '+19990000101', position: '' };
const AUTH = { uid: ID, email: `${PROFILE.login}@khorazm-issiklik.app`, disabled: false, providerData: [{ providerId: 'password', email: `${PROFILE.login}@khorazm-issiklik.app` }],
  metadata: { creationTime: new Date(created.toMillis()).toUTCString(), lastSignInTime: new Date(created.toMillis() + 10000).toUTCString() } };
const ENV = { FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' };
const PRIVATE = path.join(os.tmpdir(), 'synthetic-operator-private-input');
const PROFILE_PATH = path.join(PRIVATE, 'profile.json');
const MAPPING_PATH = path.join(PRIVATE, 'mapping.json');
const pick = (data, fields) => Object.fromEntries(fields.map(field => [field, data[field]]));
function clone(value) {
  if (value instanceof Timestamp) return new Timestamp(value.seconds, value.nanoseconds);
  if (Array.isArray(value)) return value.map(clone);
  if (value !== null && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, clone(item)]));
  return value;
}
function user(extra = {}) { return { id: ID, ...PROFILE, photoUrl: '', role: 'member', status: 'pending', boilerhouseIds: [], sessionValidAfter: epoch, createdAt: created, ...extra }; }
function mirrored(data = user()) {
  return {
    [`users/${ID}`]: data, [`employeeDirectory/${ID}`]: clone(data),
    [`access/${ID}`]: pick(data, operator.ACCESS_FIELDS), [`userProfiles/${ID}`]: pick(data, operator.PROFILE_FIELDS),
    [`phoneClaims/${PROFILE.phone}`]: { uid: ID, createdAt: created },
  };
}
function args(extra = []) {
  return ['provision-admin', '--project', PROJECT, '--environment', 'emulator', '--private-dir', PRIVATE,
    '--uid', ID, '--profile', PROFILE_PATH, '--role', 'admin', '--status', 'active', '--boilerhouse-ids', '[]', '--session-valid-after', '1970-01-01T00:00:00.000Z', ...extra];
}
function replaceArg(values, key, value) { const result = [...values]; result[result.indexOf(key) + 1] = value; return result; }
function assertCode(action, code) { return assert.rejects(action, error => error instanceof operator.OperatorError && error.code === code); }

class FakeDb {
  constructor(initial, events) { this.docs = clone(initial); this.events = events; this.commits = 0; this.beforeWriteTransaction = null; this.failCommit = false; this.writePaths = []; }
  doc(documentPath) { return { path: documentPath, id: documentPath.split('/').at(-1) }; }
  snapshot(documentPath, fields) {
    let data = this.docs[documentPath];
    if (data !== undefined && fields) data = Object.fromEntries(fields.filter(field => Object.hasOwn(data, field)).map(field => [field, data[field]]));
    return { ref: this.doc(documentPath), id: documentPath.split('/').at(-1), exists: data !== undefined, updateTime: data === undefined ? undefined : created, data: () => clone(data) };
  }
  collection(name) {
    const db = this;
    return {
      name, fields: null, maximum: Infinity,
      select(...fields) { return { ...this, fields }; },
      limit(maximum) { return { ...this, maximum }; },
      async get() {
        db.events.push('read');
        return { docs: Object.keys(db.docs).filter(key => key.startsWith(`${name}/`) && key.split('/').length === 2).sort().slice(0, this.maximum).map(key => db.snapshot(key, this.fields)) };
      },
    };
  }
  async runTransaction(callback, options) {
    const writable = !options.readOnly;
    this.events.push(writable ? 'transaction-write-start' : 'transaction-read');
    if (writable && this.beforeWriteTransaction) this.beforeWriteTransaction(this);
    const staged = [];
    let writing = false;
    const tx = {
      getAll: async (...refs) => { assert.equal(writing, false, 'all reads precede writes'); return refs.map(ref => this.snapshot(ref.path)); },
      get: async query => { assert.equal(writing, false, 'all reads precede writes'); return query.get(); },
      set: (ref, data) => { assert.ok(writable); writing = true; staged.push([ref.path, clone(data), 'set']); this.events.push('write-staged'); },
      create: (ref, data) => { assert.ok(writable); writing = true; staged.push([ref.path, clone(data), 'create']); this.events.push('write-staged'); },
    };
    const result = await callback(tx);
    if (writable) {
      assert.equal(options.maxAttempts, 1, 'do not re-run stale backed-up changes');
      if (this.failCommit) throw new Error('synthetic transport failure with secret details');
      for (const [documentPath, , operation] of staged) if (operation === 'create') assert.equal(this.docs[documentPath], undefined);
      for (const [documentPath, data] of staged) { this.docs[documentPath] = data; this.writePaths.push(documentPath); }
      this.commits++;
      this.events.push('commit');
    }
    return result;
  }
}
function harness(initial = mirrored(), overrides = {}) {
  const events = [];
  const db = new FakeDb(initial, events);
  const files = [];
  const selected = clone(AUTH);
  const identities = { [ID]: selected };
  let openCount = 0;
  const auth = {
    async getUser(id) { events.push('auth-read'); if (!identities[id]) throw Object.assign(new Error('private identifier'), { code: 'auth/user-not-found' }); return clone(identities[id]); },
    async getUserByEmail(email) { events.push('auth-email-read'); const found = Object.values(identities).find(value => value.email === email); if (!found) throw Object.assign(new Error('private email'), { code: 'auth/user-not-found' }); return clone(found); },
  };
  const store = {
    readJson(file) { events.push('input-read'); return clone(file === PROFILE_PATH ? (overrides.profile || PROFILE) : overrides.mapping); },
    writeArtifact(name, data) { events.push(name.split('.').at(-2)); if (overrides.failFile === name.split('.').at(-2)) throw new Error('private path failure'); files.push({ name, data: clone(data) }); return name; },
  };
  const injected = { env: ENV, store, openRuntime: async () => { openCount++; return { db, auth, Timestamp, now: () => NOW, close: async () => events.push('closed') }; } };
  return { db, events, files, identities, store, injected, get openCount() { return openCount; }, run: values => operator.runCli(values || args(), injected) };
}

// CLI and destination guardrails run before Admin SDK initialization.
test('help has no side effects and documents exact confirmation/ADC/plan-only flags', async () => {
  const result = await operator.runCli(['--help'], { openRuntime: () => assert.fail('must not initialize SDK') });
  for (const term of ['ADC only', '--confirm-project', 'PLAN ONLY', 'Timestamp', '--uid', '--email']) assert.ok(result.help.includes(term));
});
test('defaults to dry-run and requires exact explicit authority and identity', () => {
  assert.equal(operator.parseArgs(args()).apply, undefined);
  for (const key of ['--uid', '--role', '--status', '--profile', '--boilerhouse-ids', '--session-valid-after', '--project', '--environment', '--private-dir']) {
    const missing = args(); missing.splice(missing.indexOf(key), 2);
    assert.throws(() => operator.parseArgs(missing), operator.OperatorError);
  }
  assert.throws(() => operator.parseArgs(args(['--email', AUTH.email])), operator.OperatorError);
  assert.throws(() => operator.parseArgs(args(['--first-user'])), operator.OperatorError);
  assert.throws(() => operator.parseArgs(args(['--uid', ID])), operator.OperatorError);
  assert.throws(() => operator.parseArgs(replaceArg(args(), '--role', 'member')), operator.OperatorError);
});
test('apply needs exact project confirmation and cannot coexist with dry-run', () => {
  for (const flags of [['--apply'], ['--confirm-project', PROJECT], ['--apply', '--confirm-project', 'demo-another'], ['--apply', '--confirm-project', PROJECT, '--dry-run']]) {
    assert.throws(() => operator.parseArgs(args(flags)), operator.OperatorError);
  }
  assert.equal(operator.parseArgs(args(['--apply', '--confirm-project', PROJECT])).apply, true);
});
test('migration apply and report write flags are rejected, never silently ignored', () => {
  const common = ['--project', PROJECT, '--environment', 'emulator', '--private-dir', PRIVATE];
  assert.throws(() => operator.parseArgs(['migrate-notifications', ...common, '--mapping', MAPPING_PATH, '--apply']), operator.OperatorError);
  assert.throws(() => operator.parseArgs(['schema-report', ...common, '--collection', 'journal', '--apply']), operator.OperatorError);
});
test('emulator hosts accept loopback only, never urls, credentials, remote IPs or invalid ports', () => {
  for (const value of ['127.0.0.1:8080', 'localhost:9099', '[::1]:8080']) assert.equal(operator.safeEmulatorHost(value), true);
  for (const value of ['0.0.0.0:8080', '192.168.1.1:8080', '127.1:8080', 'localhost.evil:8080', 'http://127.0.0.1:8080', 'user@localhost:8080', '127.0.0.1:0', 'localhost:65536', '127.0.0.1:08080', 'localhost:8080/path']) assert.equal(operator.safeEmulatorHost(value), false);
});
test('rejects production/demo mismatches, partial emulator configuration and ambient projects', async () => {
  const cases = [
    [args(), {}], [args(), { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }],
    [args(), { ...ENV, FIREBASE_AUTH_EMULATOR_HOST: 'evil.invalid:9099' }],
    [replaceArg(args(), '--project', 'actual-project'), ENV],
    [replaceArg(args(), '--environment', 'production'), {}],
    [replaceArg(replaceArg(args(), '--environment', 'production'), '--project', 'actual-project'), ENV],
    [args(), { ...ENV, GCLOUD_PROJECT: 'demo-wrong' }], [args(), { ...ENV, FIREBASE_CONFIG: '{"projectId":"demo-wrong"}' }],
    [args(), { ...ENV, FIREBASE_CONFIG: '/private/config.json' }], [args(), { ...ENV, NODE_TLS_REJECT_UNAUTHORIZED: '0' }],
    [args(), { ...ENV, UNKNOWN_EMULATOR_HOST: '127.0.0.1:4444' }],
  ];
  for (const [values, env] of cases) {
    let opened = false;
    await assert.rejects(() => operator.runCli(values, { env, openRuntime: () => { opened = true; } }), operator.OperatorError);
    assert.equal(opened, false);
  }
  operator.validateEnvironment({ project: 'actual-project', environment: 'production' }, {});
});
test('Timestamp parser keeps nanoseconds and rejects numeric/now/invalid dates', () => {
  const value = operator.parseTimestamp('2026-01-02T03:04:05.123456789Z', Timestamp);
  assert.equal(value.nanoseconds, 123456789);
  assert.equal(operator.encode(value, Timestamp).$timestamp.nanoseconds, 123456789);
  for (const input of ['0', 'now', 0, '2026-02-30T00:00:00Z', '2026-01-01', '2026-01-01T00:00:00+02:00']) assert.throws(() => operator.parseTimestamp(input, Timestamp), operator.OperatorError);
});
test('reviewed profile forbids grants, extra credential fields, malformed login/phone', async () => {
  for (const profile of [{ ...PROFILE, role: 'admin' }, { ...PROFILE, password: 'synthetic' }, { ...PROFILE, phone: '9990000101' }, { ...PROFILE, login: 'UPPERCASE' }]) {
    const h = harness({}, { profile });
    await assertCode(() => h.run(), 'REVIEWED_PROFILE');
    assert.equal(h.openCount, 0);
  }
});

test('dry-run writes only private artifacts, no database or Auth mutations and no PII summary', async () => {
  const h = harness();
  const before = clone(h.db.docs);
  const summary = await h.run();
  assert.equal(summary.mode, 'dry-run');
  assert.equal(summary.plannedWrites, 4);
  assert.equal(summary.appliedWrites, 0);
  assert.deepEqual(h.db.docs, before);
  assert.equal(h.db.commits, 0);
  assert.deepEqual(h.files.map(file => file.name.split('.').at(-2)), ['backup', 'plan']);
  for (const privateValue of [ID, AUTH.email, PROFILE.phone, PROFILE.firstName]) assert.equal(JSON.stringify(summary).includes(privateValue), false);
});
test('promotes one existing identity with backup-before-write and all four mirrors atomically', async () => {
  const h = harness({ ...mirrored(), 'access/unrelated': { role: 'admin', status: 'active', boilerhouseIds: [], sessionValidAfter: epoch } });
  const unrelated = clone(h.db.docs['access/unrelated']);
  const summary = await h.run(args(['--apply', '--confirm-project', PROJECT]));
  assert.equal(summary.appliedWrites, 4);
  assert.equal(h.db.commits, 1);
  assert.ok(h.events.indexOf('backup') < h.events.indexOf('transaction-write-start'));
  assert.ok(h.events.indexOf('plan') < h.events.indexOf('write-staged'));
  assert.deepEqual(h.db.docs[`users/${ID}`], h.db.docs[`employeeDirectory/${ID}`]);
  assert.deepEqual(h.db.docs[`access/${ID}`], pick(h.db.docs[`users/${ID}`], operator.ACCESS_FIELDS));
  assert.deepEqual(h.db.docs[`userProfiles/${ID}`], pick(h.db.docs[`users/${ID}`], operator.PROFILE_FIELDS));
  assert.deepEqual(h.db.docs[`users/${ID}`].createdAt, created);
  assert.deepEqual(h.db.docs['access/unrelated'], unrelated);
  assert.ok(h.db.writePaths.every(value => value.endsWith(`/${ID}`)));
});
test('an already matching target admin is an idempotent no-op including Timestamp precision', async () => {
  const cutoff = operator.parseTimestamp('2025-01-01T00:00:00.123456789Z', Timestamp);
  const h = harness(mirrored(user({ role: 'admin', status: 'active', sessionValidAfter: cutoff })));
  const summary = await h.run(replaceArg(args(['--apply', '--confirm-project', PROJECT]), '--session-valid-after', '2025-01-01T00:00:00.123456789Z'));
  assert.equal(summary.plannedWrites, 0);
  assert.equal(h.db.commits, 0);
  assert.equal(h.files.length, 2);
});
test('provisions an existing Auth-only signed-in identity and claims its phone atomically', async () => {
  const h = harness({});
  const summary = await h.run(args(['--apply', '--confirm-project', PROJECT]));
  assert.equal(summary.appliedWrites, 5);
  assert.equal(h.db.commits, 1);
  assert.deepEqual(Object.keys(h.db.docs[`users/${ID}`]).sort(), [...operator.USER_FIELDS].sort());
  assert.deepEqual(h.db.docs[`users/${ID}`].createdAt, created);
  assert.deepEqual(h.db.docs[`phoneClaims/${PROFILE.phone}`], { uid: ID, createdAt: Timestamp.fromMillis(NOW) });
});
test('fills missing mirrors only when existing values agree with explicit reviewed admin grant', async () => {
  const data = mirrored(user({ role: 'admin', status: 'active' }));
  delete data[`employeeDirectory/${ID}`]; delete data[`userProfiles/${ID}`];
  const h = harness(data);
  const summary = await h.run(args(['--apply', '--confirm-project', PROJECT]));
  assert.equal(summary.appliedWrites, 2);
  assert.deepEqual(h.db.writePaths.sort(), [`employeeDirectory/${ID}`, `userProfiles/${ID}`].sort());
});
test('exact email selection works without listing identities', async () => {
  const h = harness();
  const byEmail = args(); byEmail[byEmail.indexOf('--uid')] = '--email'; byEmail[byEmail.indexOf('--email') + 1] = AUTH.email;
  await h.run(byEmail);
  assert.ok(h.events.includes('auth-email-read'));
});
test('refuses disabled, never-signed-in, wrong-email, tenant, malformed or wrong-provider identities', async () => {
  const mutations = [
    identity => { identity.disabled = true; }, identity => { identity.metadata.lastSignInTime = null; },
    identity => { identity.email = 'different@khorazm-issiklik.app'; }, identity => { identity.tenantId = 'synthetic'; },
    identity => { identity.providerData = [{ providerId: 'google.com', email: AUTH.email }]; },
    identity => { identity.uid = 'different-id'; }, identity => { identity.metadata.creationTime = 'invalid'; },
  ];
  for (const mutate of mutations) {
    const h = harness(); mutate(h.identities[ID]);
    await assert.rejects(() => h.run(), operator.OperatorError);
    assert.equal(h.db.commits, 0); assert.equal(h.files.length, 0);
  }
});
test('missing Auth identity never triggers an automatic account creation', async () => {
  const h = harness(); delete h.identities[ID];
  await assert.rejects(() => h.run(), error => error.code === 'auth/user-not-found');
  assert.equal(h.db.commits, 0); assert.equal(h.files.length, 0);
});
test('refuses lowering or changing existing cutoff/assignments and blocked status', async () => {
  for (const data of [user({ sessionValidAfter: created }), user({ boilerhouseIds: ['h1'] }), user({ status: 'blocked' }), user({ role: 'admin', status: 'pending' })]) {
    const h = harness(mirrored(data));
    await assert.rejects(() => h.run(), operator.OperatorError);
    assert.equal(h.db.commits, 0); assert.equal(h.files.length, 0);
  }
  const h = harness();
  await assertCode(() => h.run(replaceArg(args(), '--session-valid-after', '2099-01-01T00:00:00Z')), 'CUTOFF_RANGE');
});
test('conflicting/legacy mirrors fail closed rather than selecting a grant or removing unknown fields', async () => {
  const states = [];
  let data = mirrored(); data[`access/${ID}`].role = 'admin'; states.push(data);
  data = mirrored(); data[`users/${ID}`].legacyToken = 'synthetic'; states.push(data);
  data = mirrored(); data[`employeeDirectory/${ID}`].phone = '+19990000102'; states.push(data);
  data = mirrored(); data[`access/${ID}`].sessionValidAfter = 0; states.push(data);
  data = mirrored(); data[`userProfiles/${ID}`].firstName = 'Different'; states.push(data);
  for (const initial of states) {
    const h = harness(initial);
    await assert.rejects(() => h.run(), operator.OperatorError);
    assert.equal(h.db.commits, 0);
  }
});
test('phone uniqueness covers existing claims, normalized legacy numbers and target extra claims', async () => {
  const states = [
    { ...mirrored(), [`phoneClaims/${PROFILE.phone}`]: { uid: 'another-person', createdAt: created } },
    { ...mirrored(), 'users/another-person': { phone: '+1 (999) 000-0101', login: 'another.person' } },
    { ...mirrored(), 'employeeDirectory/another-person': { phone: PROFILE.phone, login: 'another.person' } },
    { ...mirrored(), 'phoneClaims/+19990000999': { uid: ID, createdAt: created } },
  ];
  for (const initial of states) { const h = harness(initial); await assertCode(() => h.run(), 'PHONE_CONFLICT'); assert.equal(h.db.commits, 0); }
});
test('invalid or oversized phone inventory refuses unproved uniqueness', async () => {
  let h = harness({ ...mirrored(), 'users/legacy-no-phone': { login: 'legacy' } });
  await assertCode(() => h.run(), 'PHONE_INVENTORY_INVALID');
  const initial = mirrored();
  for (let index = 0; index < 1001; index++) initial[`users/synthetic-${index}`] = { login: `synthetic.${index}`, phone: `+1999${String(index).padStart(7, '0')}` };
  h = harness(initial);
  await assertCode(() => h.run(), 'INVENTORY_LIMIT');
});
test('assignment IDs must resolve and cannot point to archived houses', async () => {
  for (const initial of [{}, { 'boilerhouses/h1': { archived: true } }]) {
    const h = harness(initial);
    await assertCode(() => h.run(replaceArg(args(), '--boilerhouse-ids', '["h1"]')), 'ASSIGNMENT_REFERENCE');
  }
  const h = harness({ 'boilerhouses/h1': { archived: false } });
  assert.equal((await h.run(replaceArg(args(), '--boilerhouse-ids', '["h1"]'))).plannedWrites, 5);
});
test('backup or plan failure prevents every transaction write', async () => {
  for (const failFile of ['backup', 'plan']) {
    const h = harness(mirrored(), { failFile });
    await assert.rejects(() => h.run(args(['--apply', '--confirm-project', PROJECT])));
    assert.equal(h.db.commits, 0); assert.equal(h.events.includes('write-staged'), false);
  }
});
test('state/auth race between backup and transaction is refused with no automatic retry', async () => {
  let h = harness();
  h.db.beforeWriteTransaction = db => { db.docs[`users/${ID}`].createdAt = Timestamp.fromMillis(created.toMillis() + 1000); db.docs[`employeeDirectory/${ID}`].createdAt = Timestamp.fromMillis(created.toMillis() + 1000); };
  await assertCode(() => h.run(args(['--apply', '--confirm-project', PROJECT])), 'STATE_CHANGED');
  assert.equal(h.db.commits, 0);
  h = harness();
  h.db.beforeWriteTransaction = () => { h.identities[ID].disabled = true; };
  await assertCode(() => h.run(args(['--apply', '--confirm-project', PROJECT])), 'AUTH_IDENTITY');
  assert.equal(h.db.commits, 0);
});
test('ambiguous commit and failed post-commit receipt have distinct non-PII errors', async () => {
  let h = harness(); h.db.failCommit = true;
  await assertCode(() => h.run(args(['--apply', '--confirm-project', PROJECT])), 'COMMIT_OUTCOME_UNKNOWN');
  h = harness(mirrored(), { failFile: 'receipt' });
  await assertCode(() => h.run(args(['--apply', '--confirm-project', PROJECT])), 'POST_COMMIT_LOG_FAILED');
  assert.equal(h.db.commits, 1);
});
test('Auth backups never serialize custom claims, password hashes or token fields', async () => {
  const h = harness();
  Object.assign(h.identities[ID], { passwordHash: 'SYNTHETIC-HASH', passwordSalt: 'SYNTHETIC-SALT', customClaims: { token: 'SYNTHETIC-TOKEN' } });
  await h.run();
  const serialized = JSON.stringify(h.files);
  for (const value of ['SYNTHETIC-HASH', 'SYNTHETIC-SALT', 'SYNTHETIC-TOKEN', 'passwordHash', 'customClaims']) assert.equal(serialized.includes(value), false);
});

function mapping(extra = {}) { return { version: 1, projectId: PROJECT, entries: [{ legacyId: 'old-notification', senderId: ID, type: 'important', recipients: [{ uid: ID, isRead: false }] }], ...extra }; }
function notificationState(value = mapping()) {
  const data = { title: 'Synthetic message', message: 'Fixture only', type: 'system', recipientIds: [], createdAt: new Timestamp(1700000000, 123456789), sentAt: new Timestamp(1700000001, 987654321), isRead: true };
  return { mapping: value, sources: { 'old-notification': { exists: true, data, updateTime: created } }, targets: {}, identities: { [ID]: clone(AUTH) },
    access: { [ID]: pick(user({ role: 'admin', status: 'active' }), operator.ACCESS_FIELDS) }, Timestamp };
}
test('legacy migration preserves both source timestamps with exact per-recipient schema and external provenance only', () => {
  const state = notificationState();
  const result = operator.planNotifications(state);
  assert.equal(result.planOnly, true); assert.equal(result.proposals.length, 1);
  const proposed = result.proposals[0].data;
  assert.deepEqual(Object.keys(proposed).sort(), [...operator.NOTIFICATION_FIELDS].sort());
  assert.equal(proposed.createdAt.nanoseconds, 123456789);
  assert.equal(proposed.sentAt.nanoseconds, 987654321);
  assert.equal(proposed.isRead, false, 'no copying global legacy read state');
  assert.equal(proposed.type, 'important', 'only reviewed mapping type');
  assert.equal(Object.hasOwn(proposed, 'legacySourceId'), false);
  assert.equal(result.provenance[0].legacySourceId, 'old-notification');
});
test('legacy empty/broadcast audiences never expand without explicit mapping', () => {
  const value = mapping(); value.entries[0].recipients = [];
  assert.throws(() => operator.validateMapping(value, PROJECT), operator.OperatorError);
  for (const target of ['*', 'all', 'broadcast', '']) {
    const invalid = mapping(); invalid.entries[0].recipients[0].uid = target;
    assert.throws(() => operator.validateMapping(invalid, PROJECT), operator.OperatorError);
  }
  const missing = mapping(); delete missing.entries[0].recipients[0].isRead;
  assert.throws(() => operator.validateMapping(missing, PROJECT), operator.OperatorError);
  const duplicate = mapping(); duplicate.entries[0].recipients.push(clone(duplicate.entries[0].recipients[0]));
  assert.throws(() => operator.validateMapping(duplicate, PROJECT), operator.OperatorError);
});
test('mapping rejects wrong project, mass fanout, duplicate sources and unreviewed system type', () => {
  assert.throws(() => operator.validateMapping(mapping(), 'demo-wrong'), operator.OperatorError);
  const mass = mapping(); mass.entries[0].recipients = Array.from({ length: 101 }, (_, index) => ({ uid: `synthetic-${index}`, isRead: false }));
  assert.throws(() => operator.validateMapping(mass, PROJECT), operator.OperatorError);
  const duplicate = mapping(); duplicate.entries.push(clone(duplicate.entries[0]));
  assert.throws(() => operator.validateMapping(duplicate, PROJECT), operator.OperatorError);
  const system = mapping(); system.entries[0].type = 'system';
  assert.throws(() => operator.validateMapping(system, PROJECT), operator.OperatorError);
});
test('missing source dates never become current time and invalid recipients block planning', () => {
  for (const field of ['createdAt', 'sentAt']) {
    const state = notificationState(); delete state.sources['old-notification'].data[field];
    const result = operator.planNotifications(state);
    assert.equal(result.proposals.length, 0); assert.equal(result.blockedSources, 1);
    assert.ok(result.issues[0].codes.includes(`missing_or_invalid_${field}`));
  }
  const state = notificationState(); state.identities[ID].disabled = true;
  assert.equal(operator.planNotifications(state).blockedSources, 1);
});
test('deterministic target collision refuses overwrites and matching reruns are idempotent', () => {
  const state = notificationState();
  const first = operator.planNotifications(state);
  const id = first.proposals[0].path.split('/')[1];
  state.targets[id] = { exists: true, data: clone(first.proposals[0].data) };
  assert.equal(operator.planNotifications(state).proposals.length, 0);
  assert.equal(operator.planNotifications(state).unchanged, 1);
  state.targets[id].data.isRead = true;
  const conflict = operator.planNotifications(state);
  assert.equal(conflict.blockedSources, 1); assert.equal(conflict.proposals.length, 0);
});
test('already current notifications are not duplicated or remapped to another audience', () => {
  const state = notificationState();
  state.sources['old-notification'].data = operator.planNotifications(state).proposals[0].data;
  assert.equal(operator.planNotifications(state).unchanged, 1);
  state.mapping.entries[0].recipients[0].isRead = true;
  assert.equal(operator.planNotifications(state).blockedSources, 1);
});
test('migration CLI does no writes and summarizes only bounded counts plus private filename', async () => {
  const state = notificationState();
  const h = harness({ 'notifications/old-notification': state.sources['old-notification'].data, [`access/${ID}`]: state.access[ID] }, { mapping: state.mapping });
  const summary = await h.run(['migrate-notifications', '--project', PROJECT, '--environment', 'emulator', '--private-dir', PRIVATE, '--mapping', MAPPING_PATH]);
  assert.equal(summary.appliedWrites, 0); assert.equal(summary.plannedDocuments, 1); assert.equal(h.db.commits, 0);
  assert.equal(h.files.length, 1);
  assert.equal(JSON.stringify(summary).includes(ID), false);
  assert.equal(JSON.stringify(summary).includes('Synthetic message'), false);
});
test('schema report warns on missing dates, limits output, never leaks record values to stdout', async () => {
  const h = harness({ 'journal/synthetic-one': { title: 'Private title', authorId: 'Private-uid' }, 'journal/synthetic-two': {} });
  const summary = await h.run(['schema-report', '--project', PROJECT, '--environment', 'emulator', '--private-dir', PRIVATE, '--collection', 'journal', '--limit', '1']);
  assert.equal(summary.affectedDocuments, 1); assert.equal(summary.truncated, true); assert.equal(h.db.commits, 0);
  assert.ok(h.files[0].data.records[0].issues.includes('missing_or_invalid_eventDateTime'));
  assert.equal(JSON.stringify(summary).includes('Private'), false);
  assert.equal(Object.hasOwn(h.files[0].data.records[0], 'data'), false);
});
test('optional private exports redact credential-like fields instead of exporting secrets', async () => {
  const h = harness({ 'users/legacy': { newPassword: 'synthetic-secret', fcmToken: 'synthetic-token', nested: { privateKey: 'synthetic-key' } } });
  await h.run(['schema-report', '--project', PROJECT, '--environment', 'emulator', '--private-dir', PRIVATE, '--collection', 'users', '--export']);
  const serialized = JSON.stringify(h.files);
  for (const value of ['synthetic-secret', 'synthetic-token', 'synthetic-key']) assert.equal(serialized.includes(value), false);
});
test('unexpected errors suppress SDK credentials, UID, email, filesystem paths and stack traces', () => {
  const error = new Error(`synthetic-token ${AUTH.email} ${ID} C:/private/file`);
  const output = JSON.stringify(operator.publicError(error));
  for (const value of ['synthetic-token', AUTH.email, ID, 'C:/private/file', 'stack']) assert.equal(output.includes(value), false);
});

test('private artifacts cannot be written inside this repository even in ignored paths', () => {
  assert.throws(() => new operator.PrivateStore(operator.ROOT), error => error.code === 'PRIVATE_PATH');
});
test('private directory rejects any other Git worktree, even if local permissions are restrictive', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'operator-git-test-'));
  try {
    fs.writeFileSync(path.join(directory, '.git'), 'gitdir: synthetic-nonexistent');
    fs.mkdirSync(path.join(directory, 'private'), { mode: 0o700 });
    assert.throws(() => new operator.PrivateStore(path.join(directory, 'private')), error => error.code === 'PRIVATE_PATH');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
test('Windows private store verifies protected ACLs and restricts artifact inheritance', { skip: process.platform !== 'win32' }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'operator-acl-test-'));
  const permissionScript = `$ErrorActionPreference='Stop'; $p=$env:ISSIQLIK_OPERATOR_TEST_DIRECTORY; ` +
    `$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User; ` +
    `$acl=New-Object System.Security.AccessControl.DirectorySecurity; $acl.SetOwner($sid); $acl.SetAccessRuleProtection($true,$false); ` +
    `$rule=[System.Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'); ` +
    `$acl.AddAccessRule($rule); Set-Acl -LiteralPath $p -AclObject $acl`;
  try {
    execFileSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', permissionScript], {
      env: { ...process.env, ISSIQLIK_OPERATOR_TEST_DIRECTORY: directory }, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
    });
    const store = new operator.PrivateStore(directory);
    const input = path.join(directory, 'profile.json');
    fs.writeFileSync(input, JSON.stringify(PROFILE));
    assert.deepEqual(store.readJson(input), PROFILE);
    store.writeArtifact('synthetic.backup.json', { createdAt: created }, Timestamp);
    assert.throws(() => store.writeArtifact('synthetic.backup.json', {}, Timestamp));
    execFileSync('icacls.exe', [directory, '/grant', '*S-1-1-0:(OI)(CI)R'], {
      stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
    });
    assert.throws(() => new operator.PrivateStore(directory), error => error.code === 'PRIVATE_PERMISSIONS');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('POSIX private store enforces ownership permissions, exclusive artifacts and private inputs', { skip: process.platform === 'win32' }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'operator-private-test-'));
  fs.chmodSync(directory, 0o700);
  try {
    const store = new operator.PrivateStore(directory);
    const input = path.join(directory, 'profile.json');
    fs.writeFileSync(input, JSON.stringify(PROFILE), { mode: 0o600 });
    assert.deepEqual(store.readJson(input), PROFILE);
    const name = 'synthetic.backup.json';
    store.writeArtifact(name, { at: new Timestamp(1, 123456789) }, Timestamp);
    assert.equal(fs.statSync(path.join(directory, name)).mode & 0o077, 0);
    assert.throws(() => store.writeArtifact(name, {}, Timestamp));
    fs.chmodSync(input, 0o644);
    assert.throws(() => store.readJson(input), error => error.code === 'PRIVATE_PERMISSIONS');
    fs.chmodSync(directory, 0o755);
    assert.throws(() => new operator.PrivateStore(directory), error => error.code === 'PRIVATE_PERMISSIONS');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
test('POSIX private paths reject symlinks, input hardlinks and paths outside the private directory', { skip: process.platform === 'win32' }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'operator-links-test-'));
  try {
    const privateDir = path.join(directory, 'private'); fs.mkdirSync(privateDir, { mode: 0o700 });
    const outside = path.join(directory, 'outside.json'); fs.writeFileSync(outside, '{}', { mode: 0o600 });
    const store = new operator.PrivateStore(privateDir);
    assert.throws(() => store.readJson(outside), error => error.code === 'PRIVATE_INPUT');
    const link = path.join(privateDir, 'link.json'); fs.symlinkSync(outside, link);
    assert.throws(() => store.readJson(link), error => error.code === 'PRIVATE_PATH');
    const hardlink = path.join(privateDir, 'hardlink.json'); fs.linkSync(outside, hardlink);
    assert.throws(() => store.readJson(hardlink), error => error.code === 'PRIVATE_INPUT');
    const directoryLink = path.join(directory, 'private-link'); fs.symlinkSync(privateDir, directoryLink);
    assert.throws(() => new operator.PrivateStore(directoryLink), error => error.code === 'PRIVATE_PATH');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
