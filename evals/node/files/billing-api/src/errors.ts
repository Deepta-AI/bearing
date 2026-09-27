/** Base class for errors a client may see; the router maps them to the envelope. */
export class AppError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/** A missing resource, or one owned by another account. */
export class NotFoundError extends AppError {
  constructor(what: string) {
    super(404, 'not_found', `${what} not found`);
  }
}

/** Bad input from the client. */
export class ValidationError extends AppError {
  constructor(message: string) {
    super(400, 'validation_error', message);
  }
}

/** No key, or a key that matches no account. */
export class UnauthorizedError extends AppError {
  constructor() {
    super(401, 'unauthorized', 'missing or unknown api key');
  }
}

/** The one mapping from any thrown value to a status and the error envelope. */
export function toErrorResponse(err: unknown, requestId: string): { status: number; body: unknown } {
  if (err instanceof AppError) {
    return { status: err.status, body: { error: { code: err.code, message: err.message, requestId } } };
  }
  return {
    status: 500,
    body: { error: { code: 'internal', message: 'internal error', requestId } },
  };
}
