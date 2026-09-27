import Database from 'better-sqlite3';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS accounts (
  id    INTEGER PRIMARY KEY,
  code  TEXT NOT NULL UNIQUE,
  name  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS entries (
  id         INTEGER PRIMARY KEY,
  posted_on  TEXT NOT NULL,
  memo       TEXT NOT NULL,
  source_ref TEXT UNIQUE
);
CREATE TABLE IF NOT EXISTS lines (
  entry_id     INTEGER NOT NULL REFERENCES entries(id),
  account_id   INTEGER NOT NULL REFERENCES accounts(id),
  amount_paise INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS memo_rules (
  pattern      TEXT NOT NULL,
  account_code TEXT NOT NULL REFERENCES accounts(code),
  priority     INTEGER NOT NULL DEFAULT 100
);
`;

// Opens the ledger. Amounts are integer paise and some running totals pass
// 2^53, so every integer is read as a BigInt.
export function open(path) {
  const db = new Database(path);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.defaultSafeIntegers(true);
  // Memo rules are regular expressions matched inside SQL.
  db.function('regexp', { deterministic: true }, (pattern, value) =>
    new RegExp(pattern, 'i').test(value) ? 1 : 0,
  );
  db.exec(SCHEMA);
  return db;
}
