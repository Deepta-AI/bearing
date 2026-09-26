import { connection } from "next/server";

import { serverEnv } from "@/env.server";

// Readiness: this app can serve pages, which means the API it renders from
// answers. 503 with the failed check otherwise, so a rollout waits. The
// uncached fetch keeps it request-time; connection() says so explicitly.
export async function GET(): Promise<Response> {
  await connection();
  try {
    const response = await fetch(`${serverEnv.API_URL}/healthz`, {
      signal: AbortSignal.timeout(2_000),
    });
    if (!response.ok) {
      throw new Error(`API answered ${String(response.status)}`);
    }
  } catch {
    return Response.json(
      { status: "unavailable", checks: { api: "failed" } },
      { status: 503, headers: { "cache-control": "no-store" } },
    );
  }
  return Response.json({ status: "ok", checks: { api: "ok" } });
}
