import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { z } from "zod";
import { getCurrentOrg } from "@/lib/current-org";
import { ledger } from "@/lib/ledger";
import { InvoiceSchema, SummarySchema, type Invoice, type Summary } from "./schemas";

export const invoicesTag = (orgId: string) => `invoices:${orgId}`;

export async function listInvoices(orgId: string): Promise<Invoice[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag(invoicesTag(orgId));
  return z.array(InvoiceSchema).parse(await ledger(orgId, "/invoices"));
}

export async function getInvoiceSummary(): Promise<Summary> {
  "use cache";
  cacheLife("hours");
  cacheTag("invoice-summary");
  return SummarySchema.parse(await ledger(getCurrentOrg(), "/invoices/summary"));
}

export async function voidInvoiceById(orgId: string, id: string): Promise<void> {
  await ledger(orgId, `/invoices/${id}/void`, { method: "POST" });
}

export async function deleteInvoiceById(orgId: string, id: string): Promise<void> {
  await ledger(orgId, `/invoices/${id}`, { method: "DELETE" });
}

export async function markInvoicePaid(orgId: string, id: string): Promise<void> {
  await ledger(orgId, `/invoices/${id}/mark-paid`, { method: "POST" });
}
