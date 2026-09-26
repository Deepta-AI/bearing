import { pino, type Logger, type LoggerOptions } from "pino";

import { type Config } from "./config.js";

/**
 * loggerOptions builds the pino options Fastify uses for every log line.
 * JSON lines by default; LOG_PRETTY=true switches to pino-pretty for a
 * terminal. Credentials in headers are redacted before they are written.
 */
export function loggerOptions(config: Pick<Config, "LOG_LEVEL" | "LOG_PRETTY">): LoggerOptions {
  return {
    level: config.LOG_LEVEL,
    redact: {
      paths: ["req.headers.authorization", "req.headers.cookie", 'res.headers["set-cookie"]'],
      censor: "[redacted]",
    },
    ...(config.LOG_PRETTY
      ? {
          transport: {
            target: "pino-pretty",
            options: { colorize: true, translateTime: "HH:MM:ss" },
          },
        }
      : {}),
  };
}

/** createLogger is the one place a pino instance is made; Fastify gets it as loggerInstance. */
export function createLogger(config: Pick<Config, "LOG_LEVEL" | "LOG_PRETTY">): Logger {
  return pino(loggerOptions(config));
}
