import { ValidationError } from './errors.ts';
import { intParam } from './validate.ts';

/** The position after the last row of a page: its created_at and id. */
export type Cursor = { createdAt: string; id: string };

/** Page size bounds from docs/API.md. */
export const PAGE = { min: 1, max: 100, fallback: 20 } as const;

/** Encodes a cursor as opaque base64url. */
export function encodeCursor(c: Cursor): string {
  return Buffer.from(`${c.createdAt}|${c.id}`, 'utf8').toString('base64url');
}

/** Decodes a cursor from the query; a malformed one is a validation error. */
export function decodeCursor(raw: string | null): Cursor | null {
  if (raw === null || raw === '') return null;
  const text = Buffer.from(raw, 'base64url').toString('utf8');
  const sep = text.indexOf('|');
  if (sep <= 0 || sep === text.length - 1) throw new ValidationError('cursor is malformed');
  return { createdAt: text.slice(0, sep), id: text.slice(sep + 1) };
}

/** Reads `limit` and `cursor` from a query string per docs/API.md. */
export function pageParams(query: URLSearchParams): { limit: number; after: Cursor | null } {
  const limit = intParam(query.get('limit'), { name: 'limit', ...PAGE });
  return { limit, after: decodeCursor(query.get('cursor')) };
}
