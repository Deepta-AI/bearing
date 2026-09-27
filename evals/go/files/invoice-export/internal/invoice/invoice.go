// Package invoice holds the invoice rules. It knows nothing of SQL or HTTP.
package invoice

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// Status is an invoice's place in its lifecycle.
type Status string

// The invoice statuses.
const (
	StatusDraft Status = "draft"
	StatusOpen  Status = "open"
	StatusPaid  Status = "paid"
)

// Invoice is one merchant invoice.
type Invoice struct {
	ID          int64
	AccountID   int64
	Number      string
	AmountPaise int64
	Status      Status
	DueOn       time.Time
	CreatedAt   time.Time
	PaidAt      *time.Time
}

// Errors the handlers map to status codes.
var (
	ErrNotFound     = errors.New("invoice not found")
	ErrInvalidState = errors.New("invoice status does not allow this")
)

// Repo is the storage the service needs.
type Repo interface {
	// ListForAccount returns the account's invoices, newest first. An
	// empty status means every status.
	ListForAccount(ctx context.Context, accountID int64, status Status) ([]Invoice, error)
	// GetForAccount returns ErrNotFound when the invoice does not exist or
	// belongs to another account.
	GetForAccount(ctx context.Context, accountID, id int64) (Invoice, error)
	// Get loads an invoice by id alone, with no account check. Only the
	// nightly reconciliation job uses it.
	Get(ctx context.Context, id int64) (Invoice, error)
	// Export returns up to limit of the account's invoices with the given
	// status (every status when empty), ordered by orderBy.
	Export(ctx context.Context, accountID int64, status Status, orderBy string, limit int) ([]Invoice, error)
	// SetStatus writes status and paidAt for the account's invoice.
	SetStatus(ctx context.Context, accountID, id int64, status Status, paidAt *time.Time) error
}

// Service applies the invoice rules on top of a Repo.
type Service struct {
	Repo Repo
	Now  func() time.Time
}

// List returns the account's invoices with the given status.
func (s *Service) List(ctx context.Context, accountID int64, status Status) ([]Invoice, error) {
	invs, err := s.Repo.ListForAccount(ctx, accountID, status)
	if err != nil {
		return nil, fmt.Errorf("list invoices for account %d: %w", accountID, err)
	}
	return invs, nil
}

// Get returns one of the account's invoices.
func (s *Service) Get(ctx context.Context, accountID, id int64) (Invoice, error) {
	inv, err := s.Repo.GetForAccount(ctx, accountID, id)
	if err != nil {
		return Invoice{}, fmt.Errorf("get invoice %d: %w", id, err)
	}
	return inv, nil
}

// MarkPaid records a manual payment on an open invoice.
func (s *Service) MarkPaid(ctx context.Context, accountID, id int64) (Invoice, error) {
	inv, err := s.Repo.GetForAccount(ctx, accountID, id)
	if err != nil {
		return Invoice{}, fmt.Errorf("mark invoice %d paid: %w", id, err)
	}
	if inv.Status != StatusOpen {
		return Invoice{}, fmt.Errorf("mark invoice %d paid from %s: %w", id, inv.Status, ErrInvalidState)
	}
	now := s.Now().UTC()
	if err := s.Repo.SetStatus(ctx, accountID, id, StatusPaid, &now); err != nil {
		return Invoice{}, fmt.Errorf("mark invoice %d paid: %w", id, err)
	}
	inv.Status, inv.PaidAt = StatusPaid, &now
	return inv, nil
}

// Export returns the account's invoices for a CSV download.
func (s *Service) Export(ctx context.Context, accountID int64, status Status, orderBy string, limit int) ([]Invoice, error) {
	invs, err := s.Repo.Export(ctx, accountID, status, orderBy, limit)
	if err != nil {
		return nil, fmt.Errorf("export invoices for account %d: %w", accountID, err)
	}
	return invs, nil
}
