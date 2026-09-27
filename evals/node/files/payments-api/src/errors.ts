import type { FastifyInstance } from 'fastify';
import { hasZodFastifySchemaValidationErrors } from 'fastify-type-provider-zod';

/** Base class for errors a client may see. */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** Missing, or owned by another account. */
export class NotFoundError extends AppError {
  constructor(what: string) {
    super(404, 'not_found', `${what} not found`);
  }
}

/** The request conflicts with the current state. */
export class ConflictError extends AppError {
  constructor(message: string) {
    super(409, 'conflict', message);
  }
}

/** Bad input the schema could not express. */
export class BadRequestError extends AppError {
  constructor(message: string) {
    super(400, 'bad_request', message);
  }
}

/** The one mapping from thrown errors to the JSON envelope. */
export function registerErrorHandling(app: FastifyInstance): void {
  app.setErrorHandler((err, request, reply) => {
    const requestId = request.id;
    if (hasZodFastifySchemaValidationErrors(err)) {
      return reply.status(400).send({ error: { code: 'validation_error', message: err.message, requestId } });
    }
    if (err instanceof AppError) {
      return reply.status(err.status).send({ error: { code: err.code, message: err.message, requestId } });
    }
    request.log.error({ err }, 'unhandled error');
    return reply.status(500).send({ error: { code: 'internal', message: 'internal error', requestId } });
  });
}
