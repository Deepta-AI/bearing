// Minimal leveled logger. Production defaults to info (SHOP-150).
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const fallback = process.env.NODE_ENV === "production" ? "info" : "debug";
const min = LEVELS[process.env.LOG_LEVEL || fallback] ?? 10;

export function log(level, msg, fields = {}) {
  if (LEVELS[level] < min) return;
  process.stdout.write(JSON.stringify({ level, msg, ...fields }) + "\n");
}
