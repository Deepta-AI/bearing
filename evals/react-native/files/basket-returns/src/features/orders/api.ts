import { apiFetch } from '@/lib/api';

import { orderDetailSchema, type OrderDetail } from './schemas';

/** GET /v1/orders/{id}. */
export function fetchOrder(id: string): Promise<OrderDetail> {
  return apiFetch(`/v1/orders/${encodeURIComponent(id)}`, orderDetailSchema);
}
