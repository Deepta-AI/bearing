// The storefront's analytics module. Pages call track(); the router calls
// screen(). Nothing is sent before the cookie banner is accepted.
export function createAnalytics({ post, appVersion }) {
  let consent = false;
  return {
    setConsent(value) {
      consent = value;
    },
    track(event, props = {}) {
      if (!consent) return false;
      post('/collect', { event, props, context: { platform: 'web', app_version: appVersion }, sent_at: new Date().toISOString() });
      return true;
    },
    screen(name) {
      return this.track('screen_viewed', { screen: name });
    },
  };
}
