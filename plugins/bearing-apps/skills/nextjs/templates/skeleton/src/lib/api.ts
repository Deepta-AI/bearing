import "server-only";

import type { z } from "zod";

import { serverEnv } from "@/env.server";

export type ApiErrorCode = "network" | "http" | "invalid_json" | "invalid_response";

/** ApiError is the only error apiFetch throws; callers switch on code and status. */
export class ApiError extends Error {
  readonly code: ApiErrorCode;
  readonly status: number;
  readonly details: unknown;

  constructor(code: ApiErrorCode, status: number, message: string, details?: unknown) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

/**
 * apiFetch calls the API from the server, validates the JSON body with the
 * schema and returns the typed value.
 *
 * It never caches. Under Cache Components (next.config.ts) every read is
 * request-time unless the calling feature function opts in with
 * `"use cache"`, `cacheLife(...)` and `cacheTag(...)`; a mutation then
 * calls `updateTag` in the server action (the user sees the write at once)
 * or `revalidateTag(tag, "max")` from a route handler or webhook. The
 * fetch-level `cache` and `next` options are the pre-16 model; do not mix
 * the two.
 */
export async function apiFetch<T>(
  path: string,
  schema: z.ZodType<T>,
  init: RequestInit = {},
): Promise<T> {
  const method = init.method ?? "GET";
  const headers = new Headers(init.headers);
  headers.set("Accept", "application/json");
  if (init.body !== undefined && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  let response: Response;
  try {
    response = await fetch(`${serverEnv.API_URL}${path}`, {
      signal: AbortSignal.timeout(5_000),
      ...init,
      headers,
    });
  } catch (cause) {
    throw new ApiError("network", 0, `${method} ${path}: network error`, cause);
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new ApiError(
      "http",
      response.status,
      `${method} ${path}: ${String(response.status)} ${response.statusText}`.trim(),
      body,
    );
  }

  let json: unknown;
  try {
    json = await response.json();
  } catch (cause) {
    throw new ApiError(
      "invalid_json",
      response.status,
      `${method} ${path}: body is not JSON`,
      cause,
    );
  }

  const parsed = schema.safeParse(json);
  if (!parsed.success) {
    throw new ApiError(
      "invalid_response",
      response.status,
      `${method} ${path}: response failed validation`,
      parsed.error.issues,
    );
  }
  return parsed.data;
}
