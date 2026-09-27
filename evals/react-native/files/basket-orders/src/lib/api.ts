import type { z } from 'zod';

import { getAccessToken } from './secure-store';

/** A non-2xx response from the Basket API. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: unknown,
  ) {
    super(`API responded ${status}`);
    this.name = 'ApiError';
  }
}

const BASE_URL = (process.env.EXPO_PUBLIC_API_URL ?? '').replace(/\/$/, '');

/** The only fetch in the app: base URL, bearer token, 10 s timeout, parsed body. */
export async function apiFetch<T>(
  path: string,
  schema: z.ZodType<T>,
  init: RequestInit = {},
): Promise<T> {
  const token = await getAccessToken();
  const response = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
    signal: AbortSignal.timeout(10_000),
  });
  const body: unknown = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(response.status, body);
  return schema.parse(body);
}

/** User-facing copy for any error thrown by a query or mutation. */
export function errorMessage(error: unknown): string {
  if (error instanceof ApiError && error.status === 404) return 'We could not find that.';
  if (error instanceof ApiError && error.status < 500) return 'Something about that request was not right.';
  return 'We could not reach Basket. Check your connection and try again.';
}
