"use server";

import { updateTag } from "next/cache";
import { z } from "zod";
import { invoicesTag, voidInvoiceById } from "@/features/invoices/api";
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
