// Minimal leveled logger.
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const min = LEVELS[process.env.LOG_LEVEL || "debug"] ?? 10;

export function log(level, msg, fields = {}) {
  if (LEVELS[level] < min) return;
  process.stdout.write(JSON.stringify({ level, msg, ...fields }) + "\n");
}
