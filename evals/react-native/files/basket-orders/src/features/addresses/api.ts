import { apiFetch } from '@/lib/api';

import { addressListSchema, type Address } from './schemas';

/** GET /v1/addresses. */
export async function fetchAddresses(): Promise<Address[]> {
  const page = await apiFetch('/v1/addresses', addressListSchema);
  return page.items;
}
