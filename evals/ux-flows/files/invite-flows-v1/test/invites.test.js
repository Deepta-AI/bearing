import { test } from 'node:test';
import assert from 'node:assert/strict';
import { seeded } from './helpers.js';
import { signup } from '../src/server/auth.js';
import { createInvite, acceptInvite, revokeInvite, INVITE_TTL_HOURS } from '../src/server/invites.js';
import { createLimiter } from '../src/server/rateLimit.js';

const T0 = Date.UTC(2026, 8, 1);

test('admin invites; pending invites hold Starter seats', () => {
  const { store, admin, ws } = seeded();
  for (const n of [1, 2, 3, 4]) createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: `p${n}@acme.test`, now: T0 });
  assert.throws(
    () => createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'p5@acme.test', now: T0 }),
    { code: 'SEAT_LIMIT' },
  );
});

test('members cannot invite', () => {
  const { store, admin, ws } = seeded();
  const inv = createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'm@acme.test', now: T0 });
  const { user } = signup(store, { email: 'm@acme.test', password: 'long-enough-pw', workspaceName: 'Own' });
  acceptInvite(store, { token: inv.token, userId: user.id, now: T0 });
  assert.throws(() => createInvite(store, { workspaceId: ws.id, actorId: user.id, email: 'x@acme.test', now: T0 }), { code: 'NOT_ADMIN' });
});

test('duplicate, domain and email checks', () => {
  const { store, admin, ws } = seeded({ allowedDomains: ['acme.test'] });
  createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'a@acme.test', now: T0 });
  assert.throws(() => createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'A@acme.test', now: T0 }), { code: 'INVITE_PENDING' });
  assert.throws(() => createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'b@other.test', now: T0 }), { code: 'DOMAIN_NOT_ALLOWED' });
  assert.throws(() => createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'owner@acme.test', now: T0 }), { code: 'ALREADY_MEMBER' });
});

test('links expire after INVITE_TTL_HOURS and revoked links stop working', () => {
  const { store, admin, ws } = seeded({ plan: 'pro' });
  const a = createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'late@acme.test', now: T0 });
  const b = createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'gone@acme.test', now: T0 });
  const late = signup(store, { email: 'late@acme.test', password: 'long-enough-pw', workspaceName: 'L' }).user;
  const gone = signup(store, { email: 'gone@acme.test', password: 'long-enough-pw', workspaceName: 'G' }).user;
  assert.throws(() => acceptInvite(store, { token: a.token, userId: late.id, now: T0 + INVITE_TTL_HOURS * 3600_000 }), { code: 'INVITE_EXPIRED' });
  revokeInvite(store, { workspaceId: ws.id, actorId: admin.id, inviteId: b.id });
  assert.throws(() => acceptInvite(store, { token: b.token, userId: gone.id, now: T0 }), { code: 'INVITE_REVOKED' });
});

test('accept requires the invited address', () => {
  const { store, admin, ws } = seeded({ plan: 'pro' });
  const inv = createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'work@acme.test', now: T0 });
  const other = signup(store, { email: 'personal@mail.test', password: 'long-enough-pw', workspaceName: 'P' }).user;
  assert.throws(() => acceptInvite(store, { token: inv.token, userId: other.id, now: T0 }), { code: 'EMAIL_MISMATCH' });
});

test('invite creation is limited per workspace per minute', () => {
  let t = T0;
  const allow = createLimiter({ now: () => t });
  const { store, admin, ws } = seeded({ plan: 'pro' });
  for (let n = 0; n < 10; n++) createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: `r${n}@acme.test`, allow, now: t });
  assert.throws(() => createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'r10@acme.test', allow, now: t }), { code: 'RATE_LIMITED' });
  t += 60_000;
  createInvite(store, { workspaceId: ws.id, actorId: admin.id, email: 'r10@acme.test', allow, now: t });
});
