import { backoff } from './backoff.js';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function withTimeout(promise, ms) {
  const { promise: timeout, reject } = Promise.withResolvers();
  const timer = setTimeout(() => reject(new Error(`attempt timed out after ${ms} ms`)), ms);
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

// A client error will fail the same way again; 429 asks us to come back later.
function defaultShouldRetry(err) {
  const status = err && err.status;
  if (typeof status === 'number' && status >= 400 && status < 500) return status === 429;
  return true;
}

/**
 * Call fn until it resolves or `retries` retries are spent.
 * Options: retries (3), timeoutMs per attempt (10000), baseMs, maxMs,
 * jitter, shouldRetry(err).
 */
export async function retry(fn, options = {}) {
  const { retries = 3, timeoutMs = 10000, shouldRetry = defaultShouldRetry, ...delay } = options;
  for (let attempt = 0; ; attempt++) {
    try {
      return await withTimeout(Promise.resolve().then(fn), timeoutMs);
    } catch (err) {
      if (attempt >= retries || !shouldRetry(err)) throw err;
      await sleep(backoff(attempt + 1, delay));
    }
  }
}
