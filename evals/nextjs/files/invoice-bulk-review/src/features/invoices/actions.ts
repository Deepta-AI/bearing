"use server";

import { revalidateTag, updateTag } from "next/cache";
import { z } from "zod";
import {
  deleteInvoiceById,
  invoicesTag,
  markInvoicePaid,
  voidInvoiceById,
} from "@/features/invoices/api";
import { InvoiceIdSchema } from "@/features/invoices/schemas";
import { requireSession } from "@/lib/session";

export type ActionState =
  | { status: "idle" }
  | { status: "ok" }
  | { status: "error"; message: string };

export async function voidInvoice(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const session = await requireSession();
  const parsed = InvoiceIdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { status: "error", message: z.prettifyError(parsed.error) };
  }
  try {
    await voidInvoiceById(session.orgId, parsed.data.id);
  } catch {
    return { status: "error", message: "Could not void the invoice. Try again." };
  }
  updateTag(invoicesTag(session.orgId));
  return { status: "ok" };
}

const BulkSchema = z.object({ ids: z.array(InvoiceIdSchema.shape.id).min(1).max(100) });

// Shared by the toolbar action and the nightly reconciliation job.
export async function markPaidMany(orgId: string, ids: string[]): Promise<void> {
  await Promise.all(ids.map((id) => markInvoicePaid(orgId, id)));
  updateTag(invoicesTag(orgId));
}

export async function bulkMarkPaid(_prev: ActionState, formData: FormData): Promise<ActionState> {
  try {
    const session = await requireSession();
    const parsed = BulkSchema.safeParse({ ids: formData.getAll("ids") });
    if (!parsed.success) {
      return { status: "error", message: z.prettifyError(parsed.error) };
    }
    await markPaidMany(session.orgId, parsed.data.ids);
    return { status: "ok" };
  } catch {
    return { status: "error", message: "Could not mark the invoices paid. Try again." };
  }
}

// Bulk "Remove" from the toolbar. The page binds the organisation on the
// server, so the form cannot choose it.
export async function bulkDelete(
  orgId: string,
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  await requireSession();
  const ids = formData.getAll("ids") as string[];
  for (const id of ids) {
    await deleteInvoiceById(orgId, id);
  }
  revalidateTag("invoices");
  return { status: "ok" };
}
