import { randomBytes } from 'node:crypto';

// In-memory invoice store (the production store has the same interface).
export function createStore() {
  const invoices = new Map();
  let next = 1;
  return {
    create({ merchantId, customerName, customerEmail, currency, lines }) {
      const id = `inv_${String(next++).padStart(5, '0')}`;
      const amountMinor = lines.reduce((sum, l) => sum + l.qty * l.unitMinor, 0);
      const invoice = {
        id,
        merchantId,
        number: `INV-${1000 + next}`,
        customerName,
        customerEmail,
        currency,
        lines,
        amountMinor,
        status: 'draft',
        payToken: randomBytes(16).toString('hex'),
        payerNote: null,
        receiptEmail: null,
        paidAt: null,
        paymentMethod: null,
        lastFailure: null,
        sessionId: null,
      };
      invoices.set(id, invoice);
      return invoice;
    },
    byId(id) {
      return invoices.get(id) ?? null;
    },
    withOpenSession() {
      return [...invoices.values()].filter((inv) => inv.sessionId && inv.status !== 'paid');
    },
    byToken(token) {
      for (const inv of invoices.values()) if (inv.payToken === token) return inv;
      return null;
    },
  };
}
