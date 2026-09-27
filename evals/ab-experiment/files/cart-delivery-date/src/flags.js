import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { track } from './analytics.js';

const config = JSON.parse(
  readFileSync(new URL('../config/flags.json', import.meta.url), 'utf8'),
);

function bucket(key, flag) {
  const h = createHash('sha256').update(`${key}:${flag}`).digest();
  return h.readUInt32BE(0) % 100;
}

// Called from the request middleware for every flag on every request, so
// the variant is known before any route runs.
export function variantFor(flag, req, flags = config) {
  const f = flags[flag];
  if (!f) return 'control';
  const variant = bucket(req.sessionId, flag) < f.percent ? 'treatment' : 'control';
  track('experiment_exposed', {
    experiment: flag,
    variant,
    session_id: req.sessionId,
  });
  return variant;
}

export function assignAll(req, flags = config) {
  const out = {};
  for (const name of Object.keys(flags)) out[name] = variantFor(name, req, flags);
  return out;
}
