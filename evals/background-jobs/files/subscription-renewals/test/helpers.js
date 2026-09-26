import { openDb, migrate } from '../src/db.js';

export function seededDb() {
  const db = openDb(':memory:');
  migrate(db);
  const add = db.prepare(
    'INSERT INTO subscriptions (id, customer_id, plan, price_paise, next_renewal_at) VALUES (?, ?, ?, ?, ?)',
  );
  add.run('sub_1', 'cus_1', 'pro', 149900, '2026-10-01T00:00:00.000Z');
  add.run('sub_2', 'cus_2', 'basic', 49900, '2026-10-01T00:00:00.000Z');
  add.run('sub_3', 'cus_3', 'pro', 149900, '2026-10-15T00:00:00.000Z');
  return db;
}
