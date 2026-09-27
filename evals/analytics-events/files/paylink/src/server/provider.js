import { createHmac } from 'node:crypto';

// The payment provider's client.
//
// createSession() returns the provider's hosted page. When the payer leaves
// that page the provider redirects to `${returnUrl}?status=success`, for card
// payments that went through AND for UPI and netbanking payments that are
// still pending at the bank (they settle or fail minutes later). The only
// final word is the webhook:
//
//   { id: 'evt_...', type: 'payment.succeeded' | 'payment.failed',
//     created_at: ISO time,
//     data: { invoice_id, amount_minor, currency,
//             method: 'card' | 'upi' | 'netbanking',
//             failure_code: 'card_declined' | 'insufficient_funds' | 'expired' | 'bank_unavailable' | null,
//             failure_message: text from the bank, may name the card holder } }
//
// Webhooks are delivered at least once: the provider retries until it gets a
// 2xx, so the same event id can arrive two or more times. It gives up after
// three days of failed deliveries; getPayment() is the way to ask directly:
//
//   { session_id, status: 'pending' | 'succeeded' | 'failed', invoice_id,
//     amount_minor, currency, method, paid_at: ISO time or null }
export class FakeProvider {
  constructor(secret = 'whsec_test') {
    this.secret = secret;
    this.sessions = [];
    this.results = new Map();
  }

  // Test helper: what the provider will report for a session.
  settle(sessionId, status, paidAt = null) {
    this.results.set(sessionId, { status, paidAt });
  }

  async getPayment(sessionId) {
    const s = this.sessions.find((x) => x.id === sessionId);
    const r = this.results.get(sessionId) ?? { status: 'pending', paidAt: null };
    return {
      session_id: sessionId,
      status: r.status,
      invoice_id: s.invoiceId,
      amount_minor: s.amountMinor,
      currency: s.currency,
      method: s.method,
      paid_at: r.paidAt,
    };
  }

  async createSession({ invoiceId, amountMinor, currency, method, returnUrl }) {
    const session = { id: `cs_${this.sessions.length + 1}`, invoiceId, amountMinor, currency, method, returnUrl };
    this.sessions.push(session);
    return { sessionId: session.id, redirectUrl: `https://pay.provider.example/s/${session.id}` };
  }

  sign(body) {
    return createHmac('sha256', this.secret).update(JSON.stringify(body)).digest('hex');
  }
}
