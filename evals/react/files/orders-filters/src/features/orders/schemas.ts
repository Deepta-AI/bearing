import { z } from "zod";

export const OrderStatusSchema = z.enum(["pending", "paid", "shipped", "cancelled"]);
export type OrderStatus = z.infer<typeof OrderStatusSchema>;

export const OrderSchema = z.object({
  id: z.string(),
  number: z.string(),
  customerEmail: z.email(),
  status: OrderStatusSchema,
  totalPaise: z.number().int().nonnegative(),
  placedAt: z.iso.datetime(),
});
export type Order = z.infer<typeof OrderSchema>;

export const OrderPageSchema = z.object({
  items: z.array(OrderSchema),
  page: z.number().int().positive(),
  pageSize: z.number().int().positive(),
  total: z.number().int().nonnegative(),
});
export type OrderPage = z.infer<typeof OrderPageSchema>;

export const OrderDetailSchema = OrderSchema.extend({
  lines: z.array(
    z.object({ sku: z.string(), name: z.string(), qty: z.number().int(), pricePaise: z.number().int() }),
  ),
});
export type OrderDetail = z.infer<typeof OrderDetailSchema>;
