import { z } from "zod";

export const CustomerSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.email(),
  phone: z.string().nullable(),
  createdAt: z.iso.datetime(),
});
export type Customer = z.infer<typeof CustomerSchema>;

export const CustomerListSchema = z.array(CustomerSchema);

// Other accounts the support API links to this one (same phone or household).
export const CustomerDetailSchema = CustomerSchema.extend({
  linkedAccounts: z.array(z.object({ id: z.string(), name: z.string() })),
});
export type CustomerDetail = z.infer<typeof CustomerDetailSchema>;
