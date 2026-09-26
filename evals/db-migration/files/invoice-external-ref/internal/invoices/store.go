// Package invoices is the invoice store.
package invoices

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

// ErrNotFound is returned when no invoice matches.
var ErrNotFound = errors.New("invoice not found")

// Invoice is one row of the invoices table.
type Invoice struct {
	ID          int64
	TenantID    int64
	Number      string
	AmountPaise int64
	Status      string
	ExternalRef sql.NullString
	PaidAt      sql.NullTime
}

// Store reads and writes invoices.
type Store struct {
	DB *sql.DB
}

// FindByExternalRef looks an invoice up by the payment provider's reference.
func (s *Store) FindByExternalRef(ctx context.Context, ref string) (Invoice, error) {
	var inv Invoice
	err := s.DB.QueryRowContext(ctx, `
		SELECT id, tenant_id, number, amount_paise, status, external_ref, paid_at
		FROM invoices
		WHERE external_ref = $1`, ref).Scan(
		&inv.ID, &inv.TenantID, &inv.Number, &inv.AmountPaise, &inv.Status, &inv.ExternalRef, &inv.PaidAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Invoice{}, ErrNotFound
	}
	return inv, err
}

// SetExternalRef records the provider's reference when a payment link is
// created for an invoice.
func (s *Store) SetExternalRef(ctx context.Context, tenantID, invoiceID int64, ref string) error {
	_, err := s.DB.ExecContext(ctx, `
		UPDATE invoices SET external_ref = $3
		WHERE tenant_id = $1 AND id = $2`, tenantID, invoiceID, ref)
	return err
}

// MarkPaid records a payment.
func (s *Store) MarkPaid(ctx context.Context, id int64, at time.Time) error {
	_, err := s.DB.ExecContext(ctx, `
		UPDATE invoices SET status = 'paid', paid_at = $2
		WHERE id = $1 AND status = 'open'`, id, at)
	return err
}
