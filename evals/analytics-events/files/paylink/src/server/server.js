import http from 'node:http';
import { createApp } from './app.js';
import { createStore } from './store.js';
import { FakeProvider } from './provider.js';
import { createServerAnalytics } from './analytics.js';

const analytics = createServerAnalytics({
  appVersion: process.env.APP_VERSION ?? 'dev',
  send: (payload) =>
    fetch(process.env.COLLECTOR_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.COLLECTOR_KEY}` },
      body: JSON.stringify(payload),
    }).catch(() => {}),
});
const handle = createApp({
  store: createStore(),
  provider: new FakeProvider(process.env.PROVIDER_WEBHOOK_SECRET),
  analytics,
  baseUrl: process.env.BASE_URL ?? 'http://localhost:8000',
  log: console.log,
});

http
  .createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const url = new URL(req.url, 'http://x');
    const out = await handle(req.method, url.pathname, raw ? JSON.parse(raw) : {}, req.headers);
    res.writeHead(out.status, { 'content-type': 'application/json' }).end(JSON.stringify(out.body ?? {}));
  })
  .listen(8000);
