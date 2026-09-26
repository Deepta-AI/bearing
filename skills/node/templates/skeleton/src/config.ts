import { z } from "zod";

// Process configuration from the environment. Construction fails fast and
// names every invalid variable at once. Secrets have no defaults. Nothing
// else in the service reads process.env.
const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  HOST: z.string().min(1).default("0.0.0.0"),
  LOG_LEVEL: z.enum(["trace", "debug", "info", "warn", "error", "fatal", "silent"]).default("info"),
  LOG_PRETTY: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  DATABASE_URL: z
    .url()
    .refine(
      (url) => url.startsWith("postgres://") || url.startsWith("postgresql://"),
      "must be a postgres:// URL",
    )
    .optional(),
  DB_POOL_MAX: z.coerce.number().int().min(1).default(10),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().min(0).default(10_000),
  OTEL_EXPORTER_OTLP_ENDPOINT: z.url().optional(),
  SERVICE_NAME: z.string().min(1).default("__REPO_SLUG__"),
  SERVICE_VERSION: z.string().min(1).default("dev"),
});

export type Config = z.infer<typeof envSchema>;

/** ConfigError lists every invalid variable, one per line. */
export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

/**
 * loadConfig parses the environment. An empty string counts as unset, so
 * `OTEL_EXPORTER_OTLP_ENDPOINT=` in .env means "off", not "invalid URL".
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const present = Object.fromEntries(
    Object.entries(env).filter(([, value]) => value !== undefined && value !== ""),
  );
  const parsed = envSchema.safeParse(present);
  if (!parsed.success) {
    throw new ConfigError(`invalid environment:\n${z.prettifyError(parsed.error)}`);
  }
  return parsed.data;
}
