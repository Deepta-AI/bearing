package refunds

import (
	"errors"
	"sync"
)

// ErrNotFound is returned when a payment does not exist.
var ErrNotFound = errors.New("payment not found")

// Payment is a captured card payment. Amounts are in paise.
type Payment struct {
	ID       string
	Captured int64
	Refunded int64
}

// Store holds payments and the refunds made against them.
type Store interface {
	Get(id string) (Payment, error)
	AddRefund(id string, amount int64) (Payment, error)
}

// MemStore is an in-memory Store used by the server and the tests.
type MemStore struct {
	mu       sync.Mutex
	payments map[string]Payment
}

func NewMemStore(ps ...Payment) *MemStore {
	s := &MemStore{payments: map[string]Payment{}}
	for _, p := range ps {
		s.payments[p.ID] = p
	}
	return s
}

func (s *MemStore) Get(id string) (Payment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.payments[id]
	if !ok {
		return Payment{}, ErrNotFound
	}
	return p, nil
}

func (s *MemStore) AddRefund(id string, amount int64) (Payment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.payments[id]
	if !ok {
		return Payment{}, ErrNotFound
	}
	p.Refunded += amount
	s.payments[id] = p
	return p, nil
}
