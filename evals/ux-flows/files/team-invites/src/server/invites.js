import { randomBytes } from 'node:crypto';
import { ApiError } from './errors.js';
import { planFor } from './plans.js';
import { nextId } from './store.js';

export const INVITE_TTL_HOURS = 48;

function roleOf(store, workspaceId, userId) {
  return store.members.find((m) => m.workspaceId === workspaceId && m.userId === userId)?.role;
}

function pendingFor(store, workspaceId, now) {
  return [...store.invites.values()].filter(
    (i) => i.workspaceId === workspaceId && i.status === 'pending' && i.expiresAt > now,
  );
}

export function createInvite(store, { workspaceId, actorId, email, allow, now = Date.now() }) {
  const ws = store.workspaces.get(workspaceId);
  if (roleOf(store, workspaceId, actorId) !== 'admin') {
    throw new ApiError(403, 'NOT_ADMIN', 'Only admins can invite people.');
  }
  const addr = String(email ?? '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(addr)) {
    throw new ApiError(422, 'INVALID_EMAIL', 'Not an email address.');
  }
  const domain = addr.split('@')[1];
  if (ws.allowedDomains.length && !ws.allowedDomains.includes(domain)) {
    throw new ApiError(422, 'DOMAIN_NOT_ALLOWED', `Only ${ws.allowedDomains.join(', ')} addresses can join.`);
  }
  const user = [...store.users.values()].find((u) => u.email === addr);
  if (user && roleOf(store, workspaceId, user.id)) {
    throw new ApiError(409, 'ALREADY_MEMBER', 'Already a member.');
  }
  const pending = pendingFor(store, workspaceId, now);
  if (pending.some((i) => i.email === addr)) {
    throw new ApiError(409, 'INVITE_PENDING', 'An invite is already pending.');
  }
  const plan = planFor(ws);
  const seatsUsed = store.members.filter((m) => m.workspaceId === workspaceId).length + pending.length;
  if (plan.seatLimit !== null && seatsUsed >= plan.seatLimit) {
    // Pending invites hold a seat so an accept can never overshoot the plan.
    throw new ApiError(402, 'SEAT_LIMIT', `${plan.name} includes ${plan.seatLimit} seats.`);
  }
  if (allow && !allow(workspaceId)) {
    throw new ApiError(429, 'RATE_LIMITED', 'Too many invites, try again in a minute.');
  }
  const invite = {
    id: nextId(store, 'inv'),
    workspaceId,
    email: addr,
    token: randomBytes(16).toString('hex'),
    status: 'pending',
    createdAt: now,
    expiresAt: now + INVITE_TTL_HOURS * 3600_000,
  };
  store.invites.set(invite.id, invite);
  return invite;
}

export function listInvites(store, { workspaceId, now = Date.now() }) {
  return pendingFor(store, workspaceId, now);
}

export function revokeInvite(store, { workspaceId, actorId, inviteId }) {
  if (roleOf(store, workspaceId, actorId) !== 'admin') {
    throw new ApiError(403, 'NOT_ADMIN', 'Only admins can revoke invites.');
  }
  const invite = store.invites.get(inviteId);
  if (!invite || invite.workspaceId !== workspaceId) throw new ApiError(404, 'NOT_FOUND', 'No such invite.');
  invite.status = 'revoked';
  return invite;
}

// Called once the invitee is signed in. The signed-in account must be the
// invited address.
export function acceptInvite(store, { token, userId, now = Date.now() }) {
  const invite = [...store.invites.values()].find((i) => i.token === token);
  if (!invite) throw new ApiError(404, 'NOT_FOUND', 'No such invite.');
  if (invite.status === 'revoked') throw new ApiError(410, 'INVITE_REVOKED', 'This invite was withdrawn.');
  if (invite.status === 'accepted') throw new ApiError(410, 'INVITE_USED', 'This invite was already used.');
  if (invite.expiresAt <= now) throw new ApiError(410, 'INVITE_EXPIRED', 'This invite has expired.');
  const user = store.users.get(userId);
  if (user.email !== invite.email) {
    throw new ApiError(403, 'EMAIL_MISMATCH', 'Signed in as a different address.');
  }
  invite.status = 'accepted';
  store.members.push({ workspaceId: invite.workspaceId, userId, role: 'member' });
  return invite;
}
