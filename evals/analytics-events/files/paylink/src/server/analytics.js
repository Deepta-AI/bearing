import { validate } from '../shared/events.js';

// The only way the server emits analytics (ADR 0004). `send` posts to the
// collector; it is injected so tests use fakeAnalytics() instead.
export function createServerAnalytics({ send, appVersion }) {
  return {
    track(event, props, { tenantId, requestId }) {
      validate(event, props);
      send({
        event,
        props,
        context: { app_version: appVersion, platform: 'server', tenant_id: tenantId, request_id: requestId },
        sent_at: new Date().toISOString(),
      });
    },
    identify(userId, { tenantId }) {
      send({ identify: userId, context: { platform: 'server', tenant_id: tenantId } });
    },
  };
}

export function fakeAnalytics() {
  const events = [];
  return {
    events,
    track(event, props, context) {
      validate(event, props);
      events.push({ event, props, context });
    },
    identify() {},
  };
}
