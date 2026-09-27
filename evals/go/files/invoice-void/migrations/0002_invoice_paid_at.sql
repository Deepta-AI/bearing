-- +goose Up
ALTER TABLE invoices ADD COLUMN paid_at timestamptz;
UPDATE invoices SET paid_at = created_at WHERE status = 'paid';

-- The status check now also ties paid_at to the paid status, so it replaces
-- the column check from 0001.
ALTER TABLE invoices DROP CONSTRAINT invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_paid_at CHECK (
    status IN ('draft', 'open', 'paid')
    AND (status = 'paid') = (paid_at IS NOT NULL)
);

-- +goose Down
ALTER TABLE invoices DROP CONSTRAINT invoices_status_paid_at;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check
    CHECK (status IN ('draft', 'open', 'paid'));
ALTER TABLE invoices DROP COLUMN paid_at;
