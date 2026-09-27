export interface BackoffOptions {
  /** First delay in milliseconds (default 100). */
  baseMs?: number;
  /** Largest delay in milliseconds (default 5000). */
  maxMs?: number;
  /** Randomise each delay between 0 and the computed value. */
  jitter?: boolean;
  /** Source of randomness for jitter (default Math.random). */
  random?: () => number;
}

export interface RetryOptions extends BackoffOptions {
  /** Retries after the first attempt (default 3). */
  retries?: number;
  /** Per-attempt timeout in milliseconds (default 10000). */
  timeoutMs?: number;
  /** Return false to stop retrying on this error. */
  shouldRetry?: (err: unknown) => boolean;
}

export function backoff(attempt: number, options?: BackoffOptions): number;

export function retry<T>(fn: () => T | Promise<T>, options?: RetryOptions): Promise<T>;
