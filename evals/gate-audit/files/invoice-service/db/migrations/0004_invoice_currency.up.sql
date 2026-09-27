ALTER TABLE invoices ADD COLUMN currency CHAR(3);
UPDATE invoices SET currency = 'INR';
ALTER TABLE invoices ALTER COLUMN currency SET NOT NULL;
