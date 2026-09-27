import { api } from "./client";

export type InvoiceStatus = "received" | "matched" | "disputed";

export interface Invoice {
  id: string;
  vendor_name: string;
  invoice_ref: string;
  amount_paise: number;
  status: InvoiceStatus;
  received_at: string;
}

export function listInvoices(page = 1) {
  return api<{ items: Invoice[]; total: number }>(`/invoices?page=${page}`);
}
