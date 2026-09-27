/**
 * Delay before retry number `attempt` (1-based): baseMs doubled per attempt,
 * capped at maxMs. With jitter, a random delay between 0 and that value.
 */
export function backoff(attempt, { baseMs = 100, maxMs = 5000, jitter = false, random = Math.random } = {}) {
  const exp = Math.min(maxMs, baseMs * 2 ** (attempt - 1));
  return jitter ? Math.floor(random() * exp) : exp;
}
