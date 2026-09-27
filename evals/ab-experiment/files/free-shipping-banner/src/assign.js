import { createHash } from 'node:crypto';

// Sticky assignment by device id: hash(device_id + ":" + experiment) mod 100.
export function assign(deviceId, experiment, percent) {
  const h = createHash('sha256').update(`${deviceId}:${experiment}`).digest();
  return h.readUInt32BE(0) % 100 < percent ? 'treatment' : 'control';
}
