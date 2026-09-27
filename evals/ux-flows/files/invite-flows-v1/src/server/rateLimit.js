// Fixed window limiter for invite creation, per workspace. Protects the
// mail provider's sender reputation (CRW-81).
export const INVITES_PER_MINUTE = 10;

export function createLimiter({ limit = INVITES_PER_MINUTE, windowMs = 60_000, now = Date.now } = {}) {
  const windows = new Map();
  return function allow(key) {
    const t = now();
    const w = windows.get(key);
    if (!w || t - w.start >= windowMs) {
      windows.set(key, { start: t, count: 1 });
      return true;
    }
    if (w.count >= limit) return false;
    w.count += 1;
    return true;
  };
}
