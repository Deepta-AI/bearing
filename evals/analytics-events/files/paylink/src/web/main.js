import { createAnalytics } from './analytics/index.js';
import { applyStoredConsent, renderConsentBanner } from './consent.js';
import { route } from './router.js';
import { renderPayPage } from './pages/pay.js';
import { renderPreview } from './pages/preview.js';

// Boots the page for `location`. The app shell has chrome and the consent
// banner; the payer shell is deliberately bare: no chrome, no login, no
// banner, so paying takes one screen.
export async function start({ location, storage, api, send, appVersion }) {
  const analytics = createAnalytics({ send, appVersion, location });
  const r = route(location.pathname);
  if (!r) return { html: '<h1>Not found</h1>', analytics };

  let html = '';
  if (r.shell === 'app') {
    const answered = applyStoredConsent(analytics, storage);
    if (!answered) html += renderConsentBanner();
    const me = await api.get('/api/me');
    analytics.setTenant(me.merchantId);
  }
  analytics.screen(r.screen);

  if (r.screen === 'pay') {
    const invoice = await api.get(`/api/pay/${r.params.token}`);
    const query = Object.fromEntries(new URLSearchParams(location.search));
    html += renderPayPage(invoice, query);
  } else if (r.screen === 'invoice_preview') {
    html += renderPreview(await api.get(`/api/invoices/${r.params.id}`));
  }
  return { html, analytics };
}
