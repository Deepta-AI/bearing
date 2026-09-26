# HTTP logging interceptor: React (Vite)

File: `src/lib/api.ts` is the only `fetch`; the interceptor wraps it.
Logging goes through `src/lib/log.ts`.

## Configuration

```ts
// src/lib/http-log.ts
const read = (key: string, fallback: string) => {
  try { return localStorage.getItem(key) ?? import.meta.env[`VITE_${key}`] ?? fallback; } catch { return fallback; }
};
export const httpLog = {
  enabled: read("LOG_HTTP", import.meta.env.DEV ? "true" : "false") === "true",
  bodies: read("LOG_HTTP_BODIES", "false") === "true",
  maxBytes: Number(read("LOG_HTTP_MAX_BYTES", "2048")),
  sample: Number(read("LOG_HTTP_SAMPLE", "1")),
};
```

## Interceptor

```ts
const REDACTED = new Set(["authorization", "cookie", "x-api-key"]);

export async function loggedFetch(input: RequestInfo, init: RequestInit = {}): Promise<Response> {
  if (!httpLog.enabled || Math.random() > httpLog.sample) return fetch(input, init);
  const url = typeof input === "string" ? input : input.url;
  const method = init.method ?? "GET";
  const start = performance.now();
  log.debug("http request", { method, url: stripQuery(url), headers: safeHeaders(init.headers),
    body: httpLog.bodies ? redactBody(truncate(init.body, httpLog.maxBytes)) : undefined });
  const res = await fetch(input, init);
  const duration_ms = Math.round(performance.now() - start);
  const body = httpLog.bodies ? redactBody(truncate(await res.clone().text(), httpLog.maxBytes)) : undefined;
  log.info("http response", { method, url: stripQuery(url), status: res.status, duration_ms,
    outcome: outcome(res.status), request_id: res.headers.get("x-request-id"), body });
  return res;
}
```

`stripQuery` removes the query string so ids and tokens in URLs never
reach the console. `safeHeaders` replaces the redacted set with
`[redacted]`. `redactBody` parses JSON when it can and replaces deny-list
keys.

## Flipping it at runtime

In the browser console: `localStorage.setItem("LOG_HTTP", "true")` and
reload. Same for `LOG_HTTP_BODIES` and `LOG_HTTP_SAMPLE`. Remove the key
to return to the build default. Build defaults come from
`VITE_LOG_HTTP*` in `.env.example`; production builds set none, so the
default is off.

## Test

Vitest with `vi.spyOn(globalThis, "fetch")` and a spy on `console.info`:
off logs nothing, on logs two lines, bodies on redacts `password`.
