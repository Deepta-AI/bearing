import { ApiError } from "@/lib/api";

import { fetchHealth } from "../api";
import type { Health } from "../schemas";

function describeError(error: unknown): string {
  return error instanceof ApiError ? error.message : "Unexpected error";
}

/**
 * HealthCard is a server component: it fetches on the server and streams
 * its HTML inside the page's Suspense boundary. No client JavaScript ships
 * for it. A failed fetch renders the error state instead of throwing, so
 * the rest of the page still renders.
 */
export async function HealthCard() {
  // The try covers the fetch only; JSX is built outside it, because a
  // render error is an error boundary's job, not a catch block's.
  let result: { ok: true; health: Health } | { ok: false; message: string };
  try {
    result = { ok: true, health: await fetchHealth() };
  } catch (error) {
    result = { ok: false, message: describeError(error) };
  }

  const content = result.ok ? (
    <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
      <dt className="text-muted-foreground">Status</dt>
      <dd className="font-medium">{result.health.status}</dd>
      <dt className="text-muted-foreground">Version</dt>
      <dd className="font-medium">{result.health.version ?? "unknown"}</dd>
    </dl>
  ) : (
    <p className="text-destructive">{result.message}</p>
  );

  return (
    <section
      aria-labelledby="health-heading"
      className="rounded-lg border bg-card p-6 text-card-foreground shadow-sm"
    >
      <h2 id="health-heading" className="text-lg font-semibold">
        API health
      </h2>
      <div role="status" aria-live="polite" className="mt-2 text-sm">
        {content}
      </div>
    </section>
  );
}
