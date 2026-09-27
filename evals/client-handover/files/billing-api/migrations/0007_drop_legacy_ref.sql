-- v2.1.0: the legacy ERP reference is no longer read anywhere. Irreversible.
ALTER TABLE invoices DROP COLUMN legacy_ref;
