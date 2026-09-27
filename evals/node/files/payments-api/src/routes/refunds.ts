import { randomUUID } from 'node:crypto';
import { eq, sql } from 'drizzle-orm';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { payments, refunds } from '../db/schema.js';
import { ConflictError, NotFoundError } from '../errors.js';
import { notifyLedger } from '../ledger.js';

/** POST and GET /payments/:id/refunds, for the support console. */
export const refundRoutes =
  (ledgerUrl: string): FastifyPluginAsyncZod =>
  async (app) => {
    app.post(
      '/payments/:id/refunds',
      {
        schema: {
          params: z.object({ id: z.string().max(64) }),
          body: z.object({ amountMinor: z.number(), reason: z.string().max(500) }),
        },
      },
      async (request, reply) => {
        request.log.info({ body: request.body, headers: request.headers }, 'refund requested');
        const [payment] = await app.db.select().from(payments).where(eq(payments.id, request.params.id));
        if (!payment) throw new NotFoundError('payment');
        if (payment.status !== 'captured') throw new ConflictError('only captured payments can be refunded');

        const [{ refunded }] = await app.db
          .select({ refunded: sql<number>`coalesce(sum(${refunds.amountMinor}), 0)` })
          .from(refunds)
          .where(eq(refunds.paymentId, payment.id));
        if (refunded + request.body.amountMinor > payment.amountMinor) {
          throw new ConflictError('refund exceeds the captured amount');
        }

        const [refund] = await app.db
          .insert(refunds)
          .values({
            id: `ref_${randomUUID()}`,
            paymentId: payment.id,
            amountMinor: request.body.amountMinor,
            reason: request.body.reason,
          })
          .returning();

        notifyLedger(ledgerUrl, refund!);
        return reply.status(201).send(refund);
      },
    );

    app.get(
      '/payments/:id/refunds',
      {
        schema: {
          params: z.object({ id: z.string().max(64) }),
          querystring: z.object({ sort: z.string().default('created_at') }),
        },
      },
      async (request) => {
        return app.db
          .select()
          .from(refunds)
          .where(sql`${refunds.paymentId} = ${request.params.id}`)
          .orderBy(sql.raw(`${request.query.sort} desc`));
      },
    );
  };
