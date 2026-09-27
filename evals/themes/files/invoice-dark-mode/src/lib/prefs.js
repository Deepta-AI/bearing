// User preferences in localStorage under the "inv." prefix. Every access is
// guarded: localStorage throws in Safari private windows and in some
// embedded webviews, and the app must still load there.
const PREFIX = 'inv.';

export function getPref(name, fallback) {
  try {
    const v = globalThis.localStorage.getItem(PREFIX + name);
    return v === null ? fallback : v;
  } catch {
    return fallback;
  }
}

export function setPref(name, value) {
  try {
    globalThis.localStorage.setItem(PREFIX + name, value);
    return true;
  } catch {
    return false;
  }
}
