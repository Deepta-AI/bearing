import { type FastifyRequest } from "fastify";
import {
  hasZodFastifySchemaValidationErrors,
  isResponseSerializationError,
} from "fastify-type-provider-zod";

import { type App } from "./app.js";

// Domain errors and their single mapping to the JSON error envelope.
// Services throw AppError subclasses; routes never build an error body;
// registerErrorHandling turns every failure into the same shape.

export interface ErrorEnvelope {
  error: {
    code: string;
    message: string;
    details: Record<string, unknown>;
    requestId: string;
  };
}

interface AppErrorOptions {
  statusCode?: number;
  code?: string;
  details?: Record<string, unknown>;
  cause?: unknown;
}

/** AppError is the base class for errors the API maps to a status code. */
export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly details: Record<string, unknown>;

  constructor(message: string, options: AppErrorOptions = {}) {
    super(message, options.cause === undefined ? undefined : { cause: options.cause });
    this.name = new.target.name;
    this.statusCode = options.statusCode ?? 400;
    this.code = options.code ?? "bad_request";
    this.details = options.details ?? {};
  }
}

/** NotFoundError: the resource does not exist or is not visible to the caller. */
export class NotFoundError extends AppError {
  constructor(message: string, options: Omit<AppErrorOptions, "statusCode" | "code"> = {}) {
    super(message, { ...options, statusCode: 404, code: "not_found" });
  }
}

/** ConflictError: the request conflicts with the current state (duplicate, stale version). */
export class ConflictError extends AppError {
  constructor(message: string, options: Omit<AppErrorOptions, "statusCode" | "code"> = {}) {
    super(message, { ...options, statusCode: 409, code: "conflict" });
  }
}

/** ServiceUnavailableError: a dependency the request needs is not reachable. */
export class ServiceUnavailableError extends AppError {
  constructor(message: string, options: Omit<AppErrorOptions, "statusCode" | "code"> = {}) {
    super(message, { ...options, statusCode: 503, code: "service_unavailable" });
  }
}

/** envelope builds the error body with the request id attached. */
export function envelope(
  request: FastifyRequest,
  code: string,
  message: string,
  details: Record<string, unknown> = {},
): ErrorEnvelope {
  return { error: { code, message, details, requestId: request.id } };
}

function clientStatus(error: unknown): number | null {
  if (typeof error === "object" && error !== null && "statusCode" in error) {
    const { statusCode } = error;
    if (typeof statusCode === "number" && statusCode >= 400 && statusCode < 500) {
      return statusCode;
    }
  }
  return null;
}

/** registerErrorHandling installs the not-found handler and the one error mapping. */
export function registerErrorHandling(app: App): void {
  app.setNotFoundHandler((request, reply) => {
    void reply
      .status(404)
      .send(envelope(request, "not_found", `route ${request.method} ${request.url} not found`));
  });

  app.setErrorHandler((error: unknown, request, reply) => {
    if (error instanceof AppError) {
      void reply
        .status(error.statusCode)
        .send(envelope(request, error.code, error.message, error.details));
      return;
    }
    if (hasZodFastifySchemaValidationErrors(error)) {
      const issues = error.validation.map((issue) => ({
        path: issue.instancePath,
        message: issue.message,
      }));
      void reply
        .status(400)
        .send(envelope(request, "validation_error", "request failed validation", { issues }));
      return;
    }
    if (isResponseSerializationError(error)) {
      request.log.error(
        { err: error, method: error.method, url: error.url },
        "response failed validation",
      );
      void reply.status(500).send(envelope(request, "internal", "internal error"));
      return;
    }
    const status = clientStatus(error);
    if (status !== null) {
      const message = error instanceof Error ? error.message : "request failed";
      void reply.status(status).send(envelope(request, "http_error", message));
      return;
    }
    // Log the stack once and hide it from the client.
    request.log.error({ err: error }, "unhandled error");
    void reply.status(500).send(envelope(request, "internal", "internal error"));
  });
}
