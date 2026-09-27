import { queryOptions, useQuery } from "@tanstack/react-query";
import { fetchOrder, fetchOrders } from "./api";

export const orderKeys = {
  all: ["orders"] as const,
  list: (page: number) => [...orderKeys.all, "list", page] as const,
  detail: (id: string) => [...orderKeys.all, "detail", id] as const,
};

export const ordersQuery = (page: number) =>
  queryOptions({
    queryKey: orderKeys.list(page),
    queryFn: ({ signal }) => fetchOrders(page, signal),
  });

export const orderQuery = (id: string) =>
  queryOptions({
    queryKey: orderKeys.detail(id),
    queryFn: ({ signal }) => fetchOrder(id, signal),
  });

export function useOrders(page: number) {
  return useQuery(ordersQuery(page));
}

export function useOrder(id: string) {
  return useQuery(orderQuery(id));
}
