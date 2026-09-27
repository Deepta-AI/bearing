import { z } from 'zod';

import { addressSchema } from '@/features/addresses/schemas';

export const orderStatusSchema = z.enum([
  'placed',
  'packed',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'refunded',
]);

export const orderSummarySchema = z.object({
  id: z.string(),
  placed_at: z.string(),
  status: orderStatusSchema,
  item_count: z.number().int(),
  total_minor: z.number().int(),
  currency: z.string(),
});

export const orderLineSchema = z.object({
  sku: z.string(),
  name: z.string(),
  qty: z.number().int(),
  unit_price_minor: z.number().int(),
});

export const orderDetailSchema = orderSummarySchema.extend({
  delivered_at: z.string().nullable(),
  delivery_address: addressSchema,
  lines: z.array(orderLineSchema),
  delivery_fee_minor: z.number().int(),
  discount_minor: z.number().int(),
});

export const orderIdSchema = z.string().regex(/^ord_[A-Za-z0-9]{12}$/);

export type OrderDetail = z.infer<typeof orderDetailSchema>;
export type OrderLine = z.infer<typeof orderLineSchema>;
