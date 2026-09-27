// Package invoices stores invoices and serves them over HTTP.
package invoices

import (
	"fmt"
	"sync"
)

// Invoice is one invoice.
type Invoice struct {
	ID       string
	TenantID string
	Customer string
	Amount   int64 // minor units
	Paid     bool
}

// Store keeps invoices in memory with sequential ids (inv_1001, inv_1002, ...).
type Store struct {
	mu   sync.Mutex
	next int
	byID map[string]*Invoice
}

// NewStore returns an empty store.
func NewStore() *Store { return &Store{next: 1001, byID: map[string]*Invoice{}} }

// Add stores inv under the next id and returns the id.
func (s *Store) Add(inv Invoice) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	inv.ID = fmt.Sprintf("inv_%d", s.next)
	s.next++
	s.byID[inv.ID] = &inv
	return inv.ID
}

// Get returns a copy of the invoice with id.
func (s *Store) Get(id string) (Invoice, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	inv, ok := s.byID[id]
	if !ok {
		return Invoice{}, false
	}
	return *inv, true
}

// ForTenant returns the tenant's invoices.
func (s *Store) ForTenant(tenant string) []Invoice {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Invoice
	for _, inv := range s.byID {
		if inv.TenantID == tenant {
			out = append(out, *inv)
		}
	}
	return out
}

// MarkPaid marks the invoice paid; false if it does not exist.
func (s *Store) MarkPaid(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	inv, ok := s.byID[id]
	if ok {
		inv.Paid = true
	}
	return ok
}
