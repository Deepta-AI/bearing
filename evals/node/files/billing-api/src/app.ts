import { createHash, randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Db } from './db.ts';
import { AppError, NotFoundError, UnauthorizedError, toErrorResponse } from './errors.ts';
import type { Logger } from './log.ts';
import { customerRoutes } from './routes/customers.ts';
import { match, type Route } from './router.ts';

const routes: Route[] = [...customerRoutes];

function accountFor(db: Db, key: string | undefined): string {
  if (!key) throw new UnauthorizedError();
  const hash = createHash('sha256').update(key).digest('hex');
  const row = db.prepare('SELECT account_id FROM api_keys WHERE key_hash = ?').get(hash) as
    | { account_id: string }
    | undefined;
  if (!row) throw new UnauthorizedError();
  return row.account_id;
}

/** Builds the request handler; the caller owns the server and the database. */
export function createApp(deps: { db: Db; log: Logger }) {
  return async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    const header = req.headers['x-request-id'];
    const requestId = typeof header === 'string' && header !== '' ? header : randomUUID();
    const log = deps.log.child({ requestId });
    const started = performance.now();
    const url = new URL(req.url ?? '/', 'http://localhost');
    let status = 500;
    let body: unknown;
    let pattern = 'unmatched';
    try {
      if (url.pathname === '/healthz') {
        status = 200;
        body = { ok: true };
      } else {
        const found = match(routes, req.method ?? 'GET', url.pathname);
        if (!found) throw new NotFoundError('route');
        pattern = found.route.pattern;
        const accountId = accountFor(deps.db, req.headers['x-api-key'] as string | undefined);
        const reply = await found.route.handle({
          db: deps.db,
          log,
          accountId,
          params: found.params,
          query: url.searchParams,
        });
        status = reply.status;
        body = reply.body;
      }
    } catch (err) {
      if (!(err instanceof AppError)) log.error('unhandled error', { err: String(err) });
      ({ status, body } = toErrorResponse(err, requestId));
    }
    res.writeHead(status, { 'content-type': 'application/json', 'x-request-id': requestId });
    res.end(JSON.stringify(body));
    if (url.pathname !== '/healthz') {
      log.info('request', {
        method: req.method,
        route: pattern,
        status,
        ms: Math.round(performance.now() - started),
      });
    }
  };
}
