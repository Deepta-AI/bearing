// Events are batched and shipped to the warehouse by the collector sidecar.
export const buffer = [];

export function track(event, props = {}) {
  buffer.push({ event, props, at: new Date().toISOString() });
}
