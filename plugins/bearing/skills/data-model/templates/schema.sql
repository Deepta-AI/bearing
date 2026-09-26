-- <scope>: database schema (PostgreSQL)
-- Written by data-model beside docs/design/data-model.md, which gives the
-- reason for every table, column, index and constraint below.
--
-- Applies in one transaction to an empty database: enum types first, then
-- tables in foreign-key order, each followed by its comments and indexes.
-- Use it as the first migration; every change after the first release is its
-- own migration (db-migration), never an edit to this file.

BEGIN;

CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'void');

-- customers: a party a tenant bills; the invoice is addressed to it.
-- Serves US-01-001, US-01-002
CREATE TABLE customers (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    display_name text NOT NULL,
    email text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customers_pkey PRIMARY KEY (id),
    CONSTRAINT chk_customers_display_name_not_blank CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_customers_email_shape CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+$')
);
COMMENT ON TABLE customers IS 'A party a tenant bills. Serves US-01-001, US-01-002.';
COMMENT ON COLUMN customers.id IS 'Surrogate key; the id every invoice references.';
COMMENT ON COLUMN customers.tenant_id IS 'The tenant that owns this customer; every query filters on it.';
COMMENT ON COLUMN customers.display_name IS 'Name printed on the invoice. [personal data]';
COMMENT ON COLUMN customers.email IS 'Address the invoice is sent to. [personal data]';
COMMENT ON COLUMN customers.created_at IS 'When the customer was added.';
COMMENT ON COLUMN customers.updated_at IS 'Last change to this row.';
-- Import and the add-customer form reject an email the tenant already has.
CREATE UNIQUE INDEX uq_customers_tenant_email ON customers (tenant_id, lower(email));

-- invoices: a bill sent to one customer, with its lifecycle status.
-- Serves US-01-002, US-01-003
CREATE TABLE invoices (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    customer_id uuid NOT NULL REFERENCES customers (id) ON DELETE RESTRICT,
    status invoice_status NOT NULL DEFAULT 'draft',
    amount_minor bigint NOT NULL,
    currency char(3) NOT NULL,
    due_on date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT invoices_pkey PRIMARY KEY (id),
    CONSTRAINT chk_invoices_amount_positive CHECK (amount_minor > 0),
    CONSTRAINT chk_invoices_currency_iso CHECK (currency ~ '^[A-Z]{3}$')
);
COMMENT ON TABLE invoices IS 'A bill sent to one customer. Serves US-01-002, US-01-003.';
COMMENT ON COLUMN invoices.id IS 'Surrogate key; the id in the invoice URL.';
COMMENT ON COLUMN invoices.tenant_id IS 'The tenant that issued the invoice; leads every list index.';
COMMENT ON COLUMN invoices.customer_id IS 'The customer billed.';
COMMENT ON COLUMN invoices.status IS 'Lifecycle: draft, sent, paid or void.';
COMMENT ON COLUMN invoices.amount_minor IS 'Total in minor units of currency (cents, paise).';
COMMENT ON COLUMN invoices.currency IS 'ISO 4217 code of amount_minor.';
COMMENT ON COLUMN invoices.due_on IS 'Calendar date payment is due, in the tenant''s time zone.';
COMMENT ON COLUMN invoices.created_at IS 'When the invoice was drafted.';
COMMENT ON COLUMN invoices.updated_at IS 'Last change to this row.';
-- Foreign-key index: a customer's invoices, and no table scan when a customer row is checked on delete.
CREATE INDEX idx_invoices_customer_id ON invoices (customer_id);
-- The invoice list: one tenant, filtered by status, newest first.
CREATE INDEX idx_invoices_tenant_status_created ON invoices (tenant_id, status, created_at DESC);

COMMIT;
