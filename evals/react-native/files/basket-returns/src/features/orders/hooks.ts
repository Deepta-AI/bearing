import { useQuery } from '@tanstack/react-query';

import { fetchOrder } from './api';

/** Query keys for orders. */
export const orderKeys = {
  all: ['orders'] as const,
  detail: (id: string) => ['orders', 'detail', id] as const,
};

/** One order. Delivered orders rarely change, so five minutes is fresh enough. */
export function useOrder(id: string, enabled = true) {
  return useQuery({
    queryKey: orderKeys.detail(id),
    queryFn: () => fetchOrder(id),
    staleTime: 5 * 60_000,
    enabled,
  });
}
