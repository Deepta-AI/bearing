/** A JSON-lines logger; `child` binds fields such as the request id. */
export type Logger = {
  info(msg: string, fields?: Record<string, unknown>): void;
  error(msg: string, fields?: Record<string, unknown>): void;
  child(fields: Record<string, unknown>): Logger;
};

/** Writes one JSON object per line to `write` (stdout by default). */
export function createLogger(
  bound: Record<string, unknown> = {},
  write: (line: string) => void = (l) => process.stdout.write(l + '\n'),
): Logger {
  const emit = (level: string, msg: string, fields?: Record<string, unknown>) =>
    write(JSON.stringify({ time: new Date().toISOString(), level, msg, ...bound, ...fields }));
  return {
    info: (msg, fields) => emit('info', msg, fields),
    error: (msg, fields) => emit('error', msg, fields),
    child: (fields) => createLogger({ ...bound, ...fields }, write),
  };
}
