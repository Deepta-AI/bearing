import { createServer } from 'node:http';
import { signup, login } from './auth.js';
import { createInvite, listInvites, revokeInvite, acceptInvite } from './invites.js';
import { createLimiter } from './rateLimit.js';
import { createStore } from './store.js';
import { ApiError } from './errors.js';

// API routes. Session handling is stubbed: the caller's user id and
// workspace id arrive as headers until CRW-44 lands real sessions.
export function routes(store, allow = createLimiter()) {
  return {
    'POST /api/signup': (b) => signup(store, b),
    'POST /api/login': (b) => login(store, b),
    'GET /api/invites': (_b, ctx) => listInvites(store, ctx),
    'POST /api/invites': (b, ctx) => createInvite(store, { ...ctx, email: b.email, allow }),
    'DELETE /api/invites/:id': (_b, ctx) => revokeInvite(store, { ...ctx, inviteId: ctx.params.id }),
    'POST /api/invites/accept': (b, ctx) => acceptInvite(store, { token: b.token, userId: ctx.actorId }),
  };
}

function match(table, method, path) {
  for (const [key, fn] of Object.entries(table)) {
    const [m, pattern] = key.split(' ');
    if (m !== method) continue;
    const re = new RegExp('^' + pattern.replace(/:(\w+)/g, '(?<$1>[^/]+)') + '$');
    const hit = path.match(re);
    if (hit) return { fn, params: hit.groups ?? {} };
  }
  return null;
}

export function start(port = 4100) {
  const table = routes(createStore());
  return createServer(async (req, res) => {
    const found = match(table, req.method, new URL(req.url, 'http://x').pathname);
    if (!found) return res.writeHead(404).end();
    let body = '';
    for await (const c of req) body += c;
    const ctx = { actorId: req.headers['x-user'], workspaceId: req.headers['x-workspace'], params: found.params };
    try {
      const out = await found.fn(body ? JSON.parse(body) : {}, ctx);
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out));
    } catch (e) {
      const err = e instanceof ApiError ? e : new ApiError(500, 'INTERNAL', 'Unexpected error.');
      res.writeHead(err.status, { 'content-type': 'application/json' }).end(JSON.stringify({ code: err.code, message: err.message }));
    }
  }).listen(port);
}

if (import.meta.url === `file://${process.argv[1]}`) start();
