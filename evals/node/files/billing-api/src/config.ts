/** Service configuration, read from the environment once at startup. */
export type Config = {
  port: number;
  dbPath: string;
  shutdownTimeoutMs: number;
};

/** Parses the environment; throws naming every bad variable. */
export function loadConfig(env: NodeJS.ProcessEnv): Config {
  const problems: string[] = [];
  const port = Number(env.PORT ?? '8080');
  if (!Number.isInteger(port) || port < 1 || port > 65535) problems.push('PORT must be 1..65535');
  const dbPath = env.BILLING_DB ?? '';
  if (dbPath === '') problems.push('BILLING_DB is required');
  const shutdownTimeoutMs = Number(env.SHUTDOWN_TIMEOUT_MS ?? '10000');
  if (!Number.isInteger(shutdownTimeoutMs) || shutdownTimeoutMs <= 0) {
    problems.push('SHUTDOWN_TIMEOUT_MS must be a positive integer');
  }
  if (problems.length) throw new Error(`config: ${problems.join('; ')}`);
  return { port, dbPath, shutdownTimeoutMs };
}
