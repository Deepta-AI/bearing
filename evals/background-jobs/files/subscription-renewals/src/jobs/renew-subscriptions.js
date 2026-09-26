import { openDb, migrate } from '../db.js';
import { FakeProvider } from '../billing.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function withRetry(fn, attempts = 3) {
  for (let i = 1; ; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i >= attempts) throw err;
      await sleep(5000);
    }
  }
}

// Charges every subscription due on or before `now` for the period
// (YYYY-MM) that `now` falls in. Returns the number charged.
export async function renewSubscriptions(db, provider, now = new Date()) {
  const period = now.toISOString().slice(0, 7);
  const due = db
    .prepare('SELECT * FROM subscriptions WHERE next_renewal_at <= ? ORDER BY id')
    .all(now.toISOString());
  let charged = 0;
  for (const sub of due) {
    if (sub.last_charged_period === period) continue;
    try {
      const ref = await withRetry(() =>
        provider.charge({ customerId: sub.customer_id, amountPaise: sub.price_paise }),
      );
      db.prepare(
        'INSERT INTO charges (subscription_id, period, amount_paise, provider_ref) VALUES (?, ?, ?, ?)',
      ).run(sub.id, period, sub.price_paise, ref);
      const next = new Date(sub.next_renewal_at);
      next.setUTCMonth(next.getUTCMonth() + 1);
      db.prepare('UPDATE subscriptions SET last_charged_period = ?, next_renewal_at = ? WHERE id = ?').run(
        period,
        next.toISOString(),
        sub.id,
      );
      charged += 1;
    } catch (err) {
      console.error('renewal failed', sub.id, err.message);
    }
  }
  return charged;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const db = openDb(process.env.BILLING_DB ?? 'billing.db');
  migrate(db);
  const n = await renewSubscriptions(db, new FakeProvider());
  console.log(`renewed ${n}`);
}
