import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { z } from "zod";
import { ledger } from "@/lib/ledger";
import { InvoiceSchema, type Invoice } from "./schemas";

export const invoicesTag = (orgId: string) => `invoices:${orgId}`;

export async function listInvoices(orgId: string): Promise<Invoice[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag(invoicesTag(orgId));
  return z.array(InvoiceSchema).parse(await ledger(orgId, "/invoices"));
}

export async function voidInvoiceById(orgId: string, id: string): Promise<void> {
  await ledger(orgId, `/invoices/${id}/void`, { method: "POST" });
}
