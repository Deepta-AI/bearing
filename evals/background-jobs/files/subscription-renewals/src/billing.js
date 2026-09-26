// Card provider client. The real provider keeps idempotency keys for 24
// hours; a key presented again after that creates a new charge.

export class ProviderTimeout extends Error {} // outcome unknown; safe to retry with the same key
export class CardDeclined extends Error {} // the card was refused; retrying will not help

export class FakeProvider {
  constructor({ timeoutsBeforeSuccess = 0, decline = new Set() } = {}) {
    this.charges = [];
    this.byKey = new Map();
    this.timeoutsLeft = timeoutsBeforeSuccess;
    this.decline = decline;
  }

  async charge({ customerId, amountPaise, idempotencyKey }) {
    if (idempotencyKey && this.byKey.has(idempotencyKey)) return this.byKey.get(idempotencyKey);
    if (this.decline.has(customerId)) throw new CardDeclined(`card declined for ${customerId}`);
    const ref = `ch_${this.charges.length + 1}`;
    this.charges.push({ ref, customerId, amountPaise, idempotencyKey });
    if (idempotencyKey) this.byKey.set(idempotencyKey, ref);
    if (this.timeoutsLeft > 0) {
      this.timeoutsLeft -= 1;
      throw new ProviderTimeout('no response within 30 s');
    }
    return ref;
  }
}
