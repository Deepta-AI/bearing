export const buffer = [];

export function track(event, props = {}) {
  buffer.push({ event, props, at: new Date().toISOString() });
}
