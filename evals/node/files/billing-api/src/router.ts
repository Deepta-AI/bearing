import type { Db } from './db.ts';
import type { Logger } from './log.ts';

/** What a handler receives: the authenticated account and the parsed request. */
export type Ctx = {
  db: Db;
  log: Logger;
  accountId: string;
  params: Record<string, string>;
  query: URLSearchParams;
};

/** A handler's result; the app serialises `body` as JSON. */
export type Reply = { status: number; body: unknown };

/** One route: method, a pattern with `:name` segments, and its handler. */
export type Route = { method: string; pattern: string; handle: (ctx: Ctx) => Reply | Promise<Reply> };

/** Finds the route for a method and path and extracts its params. */
export function match(
  routes: Route[],
  method: string,
  path: string,
): { route: Route; params: Record<string, string> } | null {
  const parts = path.split('/').filter(Boolean);
  for (const route of routes) {
    if (route.method !== method) continue;
    const pat = route.pattern.split('/').filter(Boolean);
    if (pat.length !== parts.length) continue;
    const params: Record<string, string> = {};
    let ok = true;
    for (let i = 0; i < pat.length; i++) {
      const p = pat[i] as string;
      const v = parts[i] as string;
      if (p.startsWith(':')) params[p.slice(1)] = decodeURIComponent(v);
      else if (p !== v) {
        ok = false;
        break;
      }
    }
    if (ok) return { route, params };
  }
  return null;
}
