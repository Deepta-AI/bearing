// Server-side emitter. `send` posts to the collector; tests pass a fake.
export function createEmitter({ send }) {
  return {
    track(event, props, { userId, requestId }) {
      send({ event, props, context: { platform: 'server', user_id: userId, request_id: requestId }, sent_at: new Date().toISOString() });
    },
    identify(userId) {
      send({ identify: userId });
    },
  };
}

export function fakeEmitter() {
  const events = [];
  return {
    events,
    track(event, props, context) {
      events.push({ event, props, context });
    },
    identify() {},
  };
}
