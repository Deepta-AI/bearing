import { createHash } from 'node:crypto';
import { ApiError } from './errors.js';
import { nextId } from './store.js';

const hash = (s) => createHash('sha256').update(s).digest('hex');

// Sign-up always creates the caller's own workspace and makes them its admin.
export function signup(store, { email, password, workspaceName }) {
  const addr = String(email).trim().toLowerCase();
  if ([...store.users.values()].some((u) => u.email === addr)) {
    throw new ApiError(409, 'EMAIL_TAKEN', 'An account with this email exists.');
  }
  const user = { id: nextId(store, 'usr'), email: addr, passwordHash: hash(password) };
  store.users.set(user.id, user);
  const ws = { id: nextId(store, 'ws'), name: workspaceName, plan: 'starter', allowedDomains: [] };
  store.workspaces.set(ws.id, ws);
  store.members.push({ workspaceId: ws.id, userId: user.id, role: 'admin' });
  return { user, workspace: ws };
}

// Signs in and opens the caller's workspace; the app shell shows the
// workspace returned here.
export function login(store, { email, password }) {
  const addr = String(email).trim().toLowerCase();
  const user = [...store.users.values()].find((u) => u.email === addr);
  if (!user || user.passwordHash !== hash(password)) {
    throw new ApiError(401, 'BAD_LOGIN', 'Email or password is wrong.');
  }
  const membership = store.members.find((m) => m.userId === user.id);
  return { user, workspace: store.workspaces.get(membership.workspaceId) };
}
