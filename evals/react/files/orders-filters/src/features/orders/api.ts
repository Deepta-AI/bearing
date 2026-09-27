import { apiFetch } from "@/lib/api";
import { OrderDetailSchema, OrderPageSchema } from "./schemas";

export const PAGE_SIZE = 25;

// GET /api/orders. The API also takes q, which searches the order number.
export function fetchOrders(page: number, signal?: AbortSignal) {
  const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE_SIZE) });
  return apiFetch(`/api/orders?${params}`, OrderPageSchema, { signal });
}

export function fetchOrder(id: string, signal?: AbortSignal) {
  return apiFetch(`/api/orders/${encodeURIComponent(id)}`, OrderDetailSchema, { signal });
}
