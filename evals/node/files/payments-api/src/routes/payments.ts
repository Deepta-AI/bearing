import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { createPayment, getPayment } from '../payments/service.js';

const payment = z.object({
  id: z.string(),
  accountId: z.string(),
  amountMinor: z.number().int(),
  currency: z.string(),
  status: z.enum(['authorized', 'captured', 'failed']),
  createdAt: z.date(),
});

/** GET /payments/:id and POST /payments. */
export const paymentRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/payments/:id',
    { schema: { params: z.object({ id: z.string().max(64) }), response: { 200: payment } } },
    async (request) => getPayment(app.db, request.accountId, request.params.id),
  );

  app.post(
    '/payments',
    {
      schema: {
        headers: z.object({ 'idempotency-key': z.string().min(8).max(128) }),
        body: z.object({
          amountMinor: z.number().int().positive(),
          currency: z.string().regex(/^[A-Z]{3}$/),
        }),
        response: { 201: payment },
      },
    },
    async (request, reply) => {
      const stored = await createPayment(app.db, request.accountId, request.headers['idempotency-key'], request.body);
      return reply.status(stored.statusCode).send(stored.body);
    },
  );
};
