import { z } from 'zod';

export const addressSchema = z.object({
  id: z.string(),
  label: z.string(),
  line1: z.string(),
  city: z.string(),
  pincode: z.string(),
});

export const addressListSchema = z.object({ items: z.array(addressSchema) });

export type Address = z.infer<typeof addressSchema>;
