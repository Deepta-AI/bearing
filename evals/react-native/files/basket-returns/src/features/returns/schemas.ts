import { z } from 'zod';

export const returnReasonSchema = z.enum(['damaged', 'missing', 'wrong_item', 'expired']);

export const createdReturnSchema = z.object({
  return_id: z.string(),
  status: z.literal('requested'),
});

export type ReturnReason = z.infer<typeof returnReasonSchema>;
export type CreatedReturn = z.infer<typeof createdReturnSchema>;
