import { apiFetch } from '@/lib/api';

import { healthSchema, type Health } from './schemas';

/** GET /healthz, parsed. */
export function fetchHealth(): Promise<Health> {
  return apiFetch('/healthz', healthSchema);
}
