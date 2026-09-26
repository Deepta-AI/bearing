package store

import "context"

type Invoice struct {
	ID       string
	TenantID string
	PDF      []byte
}

type Store struct{}

// InvoiceByID loads an invoice by its id.
func (s *Store) InvoiceByID(ctx context.Context, id string) (Invoice, error) {
	return Invoice{}, nil
}

func (s *Store) MarkPaid(ctx context.Context, invoiceID string, amount int64) error { return nil }

func (s *Store) CreateCustomer(ctx context.Context, tenantID, name, email, phone string) error {
	return nil
}
