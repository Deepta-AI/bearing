// Package orders serves checkout and order lookup.
package orders

import (
	"errors"
	"sync"
)

// Order is one placed order.
type Order struct {
	ID          string `json:"id"`
	CustomerID  string `json:"customer_id"`
	AmountCents int64  `json:"amount_cents"`
	ChargeID    string `json:"charge_id"`
	Status      string `json:"status"`
}

// ErrNotFound means no order has that id.
var ErrNotFound = errors.New("orders: not found")

// Store keeps orders. The deployed build uses the same in-memory store
// behind a write-through cache; persistence is out of scope here.
type Store struct {
	mu sync.Mutex
	m  map[string]Order
}

func NewStore() *Store { return &Store{m: map[string]Order{}} }

func (s *Store) Put(o Order) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.m[o.ID] = o
}

func (s *Store) Get(id string) (Order, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	o, ok := s.m[id]
	if !ok {
		return Order{}, ErrNotFound
	}
	return o, nil
}
