// Token bucket per client id. Work in progress.
export function createLimiter({ perMinute = 30 } = {}) {
  const buckets = new Map();
  return {
    allow(clientId, now = Date.now()) {
      const b = buckets.get(clientId) ?? { tokens: perMinute, at: now };
      buckets.set(clientId, b);
      return b.tokens > 0;
    },
  };
}
