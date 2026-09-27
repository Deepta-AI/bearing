// Package store reads invoices. Production uses the billing database
// through the same interface; MemStore backs local runs and tests.
package store

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"example.com/invoice-export/internal/invoice"
)

// Store lists a tenant's invoices, newest first, at most limit of them.
type Store interface {
	ListInvoices(ctx context.Context, tenantID string, limit int) ([]invoice.Invoice, error)
}

// MemStore is an in-memory Store.
type MemStore struct {
	mu   sync.RWMutex
	rows map[string][]invoice.Invoice
}

func NewMemStore() *MemStore {
	return &MemStore{rows: map[string][]invoice.Invoice{}}
}

func (m *MemStore) Add(invs ...invoice.Invoice) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, inv := range invs {
		m.rows[inv.TenantID] = append(m.rows[inv.TenantID], inv)
	}
}

func (m *MemStore) ListInvoices(_ context.Context, tenantID string, limit int) ([]invoice.Invoice, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	src := m.rows[tenantID]
	out := make([]invoice.Invoice, len(src))
	copy(out, src)
	sort.Slice(out, func(i, j int) bool { return out[i].IssuedAt.After(out[j].IssuedAt) })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

var memos = []string{
	"Monthly subscription, Growth plan",
	"Paid by card 4111 1111 1111 1111 per call with AP",
	"Usage overage\tSeptember\r\nsee attached statement",
	"Credit note applied against INV-2291",
	"Card on file 5500-0000-0000-0004 declined, retried",
	"Annual renewal, 12 seats, PO 88213",
	"",
}

// Synthetic returns n deterministic invoices for one tenant, shaped like
// production rows (memo lengths and content included). For local runs and
// load checks only.
func Synthetic(tenantID string, n int) []invoice.Invoice {
	base := time.Date(2026, 9, 1, 9, 0, 0, 0, time.UTC)
	out := make([]invoice.Invoice, n)
	for i := 0; i < n; i++ {
		issued := base.Add(-time.Duration(i) * 7 * time.Minute)
		out[i] = invoice.Invoice{
			ID:          fmt.Sprintf("inv_%s_%07d", tenantID, i),
			TenantID:    tenantID,
			Number:      fmt.Sprintf("INV-%07d", i+1),
			CustomerRef: fmt.Sprintf("cus_%05d", i%9973),
			IssuedAt:    issued,
			DueAt:       issued.Add(30 * 24 * time.Hour),
			Currency:    "USD",
			AmountMinor: int64(1999 + (i*7919)%250000),
			TaxMinor:    int64((1999 + (i*7919)%250000) / 10),
			Status:      []string{"paid", "open", "void", "paid", "paid"}[i%5],
			Memo:        memos[i%len(memos)],
		}
	}
	return out
}
