import { queryOptions, useQuery } from "@tanstack/react-query";
import { fetchCustomer, fetchCustomers } from "./api";

export const customerKeys = {
  all: ["customers"] as const,
  list: (q: string) => [...customerKeys.all, "list", q] as const,
  detail: (id: string) => [...customerKeys.all, "detail", id] as const,
};

export const customersQuery = (q: string) =>
  queryOptions({
    queryKey: customerKeys.list(q),
    queryFn: ({ signal }) => fetchCustomers(q, signal),
  });

export const customerQuery = (id: string) =>
  queryOptions({
    queryKey: customerKeys.detail(id),
    queryFn: ({ signal }) => fetchCustomer(id, signal),
  });

export function useCustomers(q: string) {
  return useQuery(customersQuery(q));
}

export function useCustomer(id: string) {
  return useQuery(customerQuery(id));
}
