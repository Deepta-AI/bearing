import { DatabaseSync } from 'node:sqlite';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  price_paise INTEGER NOT NULL,
  next_renewal_at TEXT NOT NULL,
  last_charged_period TEXT
);
CREATE TABLE IF NOT EXISTS charges (
  id INTEGER PRIMARY KEY,
  subscription_id TEXT NOT NULL REFERENCES subscriptions(id),
  period TEXT NOT NULL,
  amount_paise INTEGER NOT NULL,
  provider_ref TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  emailed_at TEXT
);
CREATE TABLE IF NOT EXISTS job_claims (
  key TEXT PRIMARY KEY,
  state TEXT NOT NULL CHECK (state IN ('in_progress', 'done')),
  claimed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  done_at TEXT
);
`;

export function openDb(path = 'billing.db') {
  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  return db;
}

export function migrate(db) {
  db.exec(SCHEMA);
}
