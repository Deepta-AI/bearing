// Package store is the PostgreSQL storage for invoices and API keys.
package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"example.com/billing-api/internal/auth"
	"example.com/billing-api/internal/invoice"
)

// Store implements invoice.Repo and auth.KeyLookup.
type Store struct{ DB *sql.DB }

const invoiceColumns = `id, account_id, number, amount_paise, status, due_on, created_at, paid_at`

func scanInvoice(row interface{ Scan(...any) error }) (invoice.Invoice, error) {
	var inv invoice.Invoice
	var status string
	var paidAt sql.NullTime
	if err := row.Scan(&inv.ID, &inv.AccountID, &inv.Number, &inv.AmountPaise, &status,
		&inv.DueOn, &inv.CreatedAt, &paidAt); err != nil {
		return invoice.Invoice{}, err
	}
	inv.Status = invoice.Status(status)
	if paidAt.Valid {
		t := paidAt.Time
		inv.PaidAt = &t
	}
	return inv, nil
}

// AccountForKey implements auth.KeyLookup.
func (s *Store) AccountForKey(ctx context.Context, key string) (int64, error) {
	var id int64
	err := s.DB.QueryRowContext(ctx, `SELECT id FROM accounts WHERE api_key = $1`, key).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, auth.ErrUnknownKey
	}
	if err != nil {
		return 0, fmt.Errorf("look up api key: %w", err)
	}
	return id, nil
}

// ListForAccount implements invoice.Repo.
func (s *Store) ListForAccount(ctx context.Context, accountID int64, status invoice.Status) ([]invoice.Invoice, error) {
	rows, err := s.DB.QueryContext(ctx,
		`SELECT `+invoiceColumns+` FROM invoices
		 WHERE account_id = $1 AND ($2 = '' OR status = $2)
		 ORDER BY created_at DESC`, accountID, string(status))
	if err != nil {
		return nil, fmt.Errorf("query invoices: %w", err)
	}
	defer rows.Close()
	var out []invoice.Invoice
	for rows.Next() {
		inv, err := scanInvoice(rows)
		if err != nil {
			return nil, fmt.Errorf("scan invoice: %w", err)
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

// GetForAccount implements invoice.Repo.
func (s *Store) GetForAccount(ctx context.Context, accountID, id int64) (invoice.Invoice, error) {
	inv, err := scanInvoice(s.DB.QueryRowContext(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE id = $1 AND account_id = $2`, id, accountID))
	if errors.Is(err, sql.ErrNoRows) {
		return invoice.Invoice{}, invoice.ErrNotFound
	}
	if err != nil {
		return invoice.Invoice{}, fmt.Errorf("select invoice %d: %w", id, err)
	}
	return inv, nil
}

// Get implements invoice.Repo. It does not check the account.
func (s *Store) Get(ctx context.Context, id int64) (invoice.Invoice, error) {
	inv, err := scanInvoice(s.DB.QueryRowContext(ctx,
		`SELECT `+invoiceColumns+` FROM invoices WHERE id = $1`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return invoice.Invoice{}, invoice.ErrNotFound
	}
	if err != nil {
		return invoice.Invoice{}, fmt.Errorf("select invoice %d: %w", id, err)
	}
	return inv, nil
}

// SetStatus implements invoice.Repo.
func (s *Store) SetStatus(ctx context.Context, accountID, id int64, status invoice.Status, paidAt *time.Time) error {
	res, err := s.DB.ExecContext(ctx,
		`UPDATE invoices SET status = $3, paid_at = $4 WHERE id = $1 AND account_id = $2`,
		id, accountID, string(status), paidAt)
	if err != nil {
		return fmt.Errorf("update invoice %d: %w", id, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("update invoice %d: %w", id, err)
	}
	if n == 0 {
		return invoice.ErrNotFound
	}
	return nil
}
