import { handlePaymentWebhook } from './webhooks.js';

// Access log line. The pay token is a credential: never write it anywhere.
export function logLine(method, path) {
  return `${method} ${path.replace(/\/pay\/[^/?]+/, '/pay/:token')}`;
}

function publicInvoice(inv) {
  return {
    number: inv.number,
    customerName: inv.customerName,
    currency: inv.currency,
    amountMinor: inv.amountMinor,
    lines: inv.lines,
    status: inv.status,
  };
}

export function createApp({ store, provider, analytics, baseUrl, log = () => {} }) {
  return async function handle(method, path, body = {}, headers = {}) {
    log(logLine(method, path));
    const requestId = headers['x-request-id'] ?? 'local';
    const merchantId = headers['x-merchant-id'];
    let m;

    if (method === 'POST' && path === '/api/invoices') {
      if (!merchantId) return { status: 401 };
      const inv = store.create({ ...body, merchantId });
      analytics.track(
        'invoice_created',
        { invoice_id: inv.id, currency: inv.currency, amount_minor: inv.amountMinor, line_count: inv.lines.length },
        { tenantId: merchantId, requestId },
      );
      return { status: 201, body: { id: inv.id, payUrl: `${baseUrl}/pay/${inv.payToken}` } };
    }

    if (method === 'GET' && (m = /^\/api\/invoices\/([\w]+)$/.exec(path))) {
      const inv = store.byId(m[1]);
      if (!inv || inv.merchantId !== merchantId) return { status: 404 };
      return { status: 200, body: publicInvoice(inv) };
    }

    if (method === 'POST' && (m = /^\/api\/invoices\/([\w]+)\/send$/.exec(path))) {
      const inv = store.byId(m[1]);
      if (!inv || inv.merchantId !== merchantId) return { status: 404 };
      inv.status = inv.status === 'paid' ? 'paid' : 'sent';
      return { status: 202 };
    }

    // The merchant records a payment made outside paylink (cash, bank transfer).
    if (method === 'POST' && (m = /^\/api\/invoices\/([\w]+)\/mark-paid$/.exec(path))) {
      const inv = store.byId(m[1]);
      if (!inv || inv.merchantId !== merchantId) return { status: 404 };
      if (inv.status === 'paid') return { status: 409, body: { error: 'already paid' } };
      inv.status = 'paid';
      inv.paidAt = new Date().toISOString();
      inv.paymentMethod = 'offline';
      return { status: 200 };
    }

    // Payer endpoints: no login, the token is the credential.
    if (method === 'GET' && (m = /^\/api\/pay\/([0-9a-f]+)$/.exec(path))) {
      const inv = store.byToken(m[1]);
      if (!inv) return { status: 404 };
      return { status: 200, body: publicInvoice(inv) };
    }

    if (method === 'POST' && (m = /^\/api\/pay\/([0-9a-f]+)\/checkout$/.exec(path))) {
      const inv = store.byToken(m[1]);
      if (!inv) return { status: 404 };
      if (inv.status === 'paid') return { status: 409, body: { error: 'already paid' } };
      if (!['card', 'upi', 'netbanking'].includes(body.method)) return { status: 400 };
      inv.receiptEmail = body.receiptEmail ?? null;
      inv.payerNote = body.note ?? null;
      const session = await provider.createSession({
        invoiceId: inv.id,
        amountMinor: inv.amountMinor,
        currency: inv.currency,
        method: body.method,
        returnUrl: `${baseUrl}/pay/${m[1]}`,
      });
      inv.sessionId = session.sessionId;
      return { status: 200, body: { redirectUrl: session.redirectUrl } };
    }

    if (method === 'POST' && path === '/webhooks/payments') {
      if (headers['x-provider-signature'] !== provider.sign(body)) return { status: 401 };
      return handlePaymentWebhook(store, body);
    }

    return { status: 404 };
  };
}
