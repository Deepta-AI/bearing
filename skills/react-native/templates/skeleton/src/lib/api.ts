import type { z } from 'zod';

import { getToken } from '@/lib/secure-store';

const DEFAULT_TIMEOUT_MS = 10_000;

/** A non-2xx response. `status` drives retry and the copy shown to the user. */
export class ApiError extends Error {
  readonly status: number;
  readonly body: unknown;

  constructor(status: number, body: unknown, message?: string) {
    super(message ?? `API responded ${status}`);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

/** Base URL from the public config. Inlined into the bundle; never a secret. */
export function apiBaseUrl(): string {
  const url = process.env.EXPO_PUBLIC_API_URL;
  if (!url) throw new Error('EXPO_PUBLIC_API_URL is not set; copy .env.example to .env');
  return url.replace(/\/$/, '');
}

/**
 * The only fetch in the app. Adds the base URL, JSON headers, the bearer
 * token when one is stored, a timeout, and parses the body with the schema
 * so call sites never see `unknown`.
 */
export async function apiFetch<T>(
  path: string,
  schema: z.ZodType<T>,
  init: RequestInit & { timeoutMs?: number } = {},
): Promise<T> {
  const { timeoutMs = DEFAULT_TIMEOUT_MS, headers, ...rest } = init;
  const token = await getToken('accessToken');
  const response = await fetch(`${apiBaseUrl()}${path}`, {
    ...rest,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  const body: unknown = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(response.status, body);
  return schema.parse(body);
}
