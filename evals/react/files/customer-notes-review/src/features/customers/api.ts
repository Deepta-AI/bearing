import { apiFetch } from "@/lib/api";
import { CustomerDetailSchema, CustomerListSchema } from "./schemas";

export function fetchCustomers(q: string, signal?: AbortSignal) {
  return apiFetch(`/api/customers?${new URLSearchParams({ q })}`, CustomerListSchema, { signal });
}

export function fetchCustomer(id: string, signal?: AbortSignal) {
  return apiFetch(`/api/customers/${encodeURIComponent(id)}`, CustomerDetailSchema, { signal });
}
