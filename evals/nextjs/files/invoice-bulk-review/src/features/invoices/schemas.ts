import { z } from "zod";

export const InvoiceSchema = z.object({
  id: z.string(),
  number: z.string(),
  customer: z.string(),
  amount: z.number().int(),
  status: z.enum(["draft", "issued", "paid", "void"]),
  dueOn: z.string(),
});
export type Invoice = z.infer<typeof InvoiceSchema>;

export const SummarySchema = z.object({
  outstanding: z.number().int(),
  overdue: z.number().int(),
  paidThisMonth: z.number().int(),
});
export type Summary = z.infer<typeof SummarySchema>;

export const InvoiceIdSchema = z.object({ id: z.string().regex(/^inv_[a-z0-9]{8}$/) });
