import Fastify, { type FastifyInstance } from 'fastify';
import { serializerCompiler, validatorCompiler, type ZodTypeProvider } from 'fastify-type-provider-zod';
import type { Db } from './db/client.js';
import { registerErrorHandling } from './errors.js';
import { paymentRoutes } from './routes/payments.js';

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
  }
  interface FastifyRequest {
    accountId: string;
  }
}

/** Builds the app with its dependencies; never listens. */
export function buildApp(deps: { db: Db; logLevel?: string }): FastifyInstance {
  const app = Fastify({
    logger: {
      level: deps.logLevel ?? 'info',
      redact: ['req.headers.authorization', 'req.headers.cookie'],
    },
    requestIdHeader: 'x-request-id',
    bodyLimit: 64 * 1024,
  }).withTypeProvider<ZodTypeProvider>();
  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);
  app.decorate('db', deps.db);
  app.decorateRequest('accountId', '');
  app.addHook('onRequest', async (request, reply) => {
    const account = request.headers['x-account-id'];
    if (typeof account !== 'string' || account === '') {
      return reply.status(401).send({ error: { code: 'unauthorized', message: 'no account', requestId: request.id } });
    }
    request.accountId = account;
  });
  app.addHook('onSend', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });
  registerErrorHandling(app);
  app.register(paymentRoutes);
  return app;
}
