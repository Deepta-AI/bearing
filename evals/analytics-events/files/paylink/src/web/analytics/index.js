import { validate } from '../../shared/events.js';

// The only way the web app emits analytics (ADR 0004). Components call
// track(); the router calls screen(). Nothing is sent or queued before
// consent: calls are dropped and counted.
export function createAnalytics({ send, appVersion, location, debug = false }) {
  let consent = false;
  let tenantId = null;
  let dropped = 0;

  return {
    setConsent(value) {
      consent = value;
    },
    setTenant(id) {
      tenantId = id;
    },
    track(event, props = {}) {
      validate(event, props);
      if (!consent) {
        dropped++;
        return false;
      }
      const payload = {
        event,
        props,
        context: { app_version: appVersion, platform: 'web', tenant_id: tenantId, page_path: location.pathname },
        sent_at: new Date().toISOString(),
      };
      if (debug) console.debug('[analytics]', payload);
      else send(payload);
      return true;
    },
    screen(name) {
      return this.track('screen_viewed', { screen: name });
    },
    get dropped() {
      return dropped;
    },
  };
}
