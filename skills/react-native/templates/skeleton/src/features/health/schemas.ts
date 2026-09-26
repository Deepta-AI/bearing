import { z } from 'zod';

/** Shape of GET /healthz on the API. The type is derived, never declared twice. */
export const healthSchema = z.object({
  status: z.string(),
  version: z.string().optional(),
});

export type Health = z.infer<typeof healthSchema>;
