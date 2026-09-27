// In-memory store until the Postgres move (CRW-60).
export function createStore() {
  return {
    users: new Map(), // id -> { id, email, passwordHash }
    workspaces: new Map(), // id -> { id, name, plan, allowedDomains: [] }
    members: [], // { workspaceId, userId, role: 'admin' | 'member' }
    invites: new Map(), // id -> { id, workspaceId, email, token, status, createdAt, expiresAt }
    seq: 1,
  };
}

export function nextId(store, prefix) {
  return `${prefix}_${store.seq++}`;
}
