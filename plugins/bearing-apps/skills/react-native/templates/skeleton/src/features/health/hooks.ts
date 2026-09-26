import { useQuery } from '@tanstack/react-query';

import { fetchHealth } from './api';

/** Query keys for the health feature. Every key in the feature comes from here. */
export const healthKeys = {
  all: ['health'] as const,
};

/** Whether the API is reachable. Refetches every minute while the screen is mounted. */
export function useHealth() {
  return useQuery({
    queryKey: healthKeys.all,
    queryFn: fetchHealth,
    staleTime: 60_000,
    refetchInterval: 60_000,
  });
}
