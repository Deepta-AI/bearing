import "server-only";

import { apiFetch } from "@/lib/api";

import { healthSchema, type Health } from "./schemas";

/**
 * fetchHealth reads GET /healthz on the API. Deliberately not cached: a
 * health card must show the answer of this request, so it runs at request
 * time and HealthCard sits under a Suspense boundary.
 *
 * Data that may lag is cached in the feature function, not in apiFetch:
 *
 *   export async function listInvoices() {
 *     "use cache";
 *     cacheLife("minutes");
 *     cacheTag("invoices");
 *     return apiFetch("/invoices", invoiceListSchema);
 *   }
 *
 * The action that changes invoices then calls updateTag("invoices").
 */
export function fetchHealth(): Promise<Health> {
  return apiFetch("/healthz", healthSchema);
}
