CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  customer_id TEXT NOT NULL REFERENCES customers(id),
  number TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('draft', 'open', 'paid', 'void')),
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  due_on TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Invoice numbers are unique per account. No other query reads invoices yet,
-- so no other index.
CREATE UNIQUE INDEX invoices_account_number ON invoices (account_id, number);
