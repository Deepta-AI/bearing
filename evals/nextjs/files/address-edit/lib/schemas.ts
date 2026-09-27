import { z } from "zod";

export const CustomerSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
});
export type Customer = z.infer<typeof CustomerSchema>;

// The shape the API returns. Old LK addresses are still readable, so this
// schema is deliberately loose; it is not the rule for saving an address.
export const AddressSchema = z.object({
  id: z.string(),
  customerId: z.string(),
  label: z.string(),
  line1: z.string(),
  line2: z.string().nullable(),
  city: z.string(),
  state: z.string(),
  pin: z.string(),
  country: z.string(),
  phone: z.string(),
});
export type Address = z.infer<typeof AddressSchema>;

export const UpdateNameSchema = z.object({
  name: z.string().trim().min(1, "Enter your name").max(80),
});
