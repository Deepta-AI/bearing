import "server-only";
import { env } from "@/env.server";

export async function ledger(orgId: string, path: string, init: RequestInit = {}) {
  const res = await fetch(`${env.LEDGER_API_URL}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${env.LEDGER_API_KEY}`,
      "X-Org-Id": orgId,
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
  if (!res.ok) throw new Error(`ledger answered ${res.status} for ${path}`);
  return res.status === 204 ? null : res.json();
}
