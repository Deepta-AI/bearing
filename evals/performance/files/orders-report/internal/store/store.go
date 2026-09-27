// Package store holds one tenant's customers and orders in memory.
package store

import (
	"errors"
	"sync"
	"time"
)

type Customer struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type Item struct {
	SKU       string `json:"sku"`
	Quantity  int    `json:"quantity"`
	UnitCents int64  `json:"unit_cents"`
}

type Order struct {
	ID         string    `json:"id"`
	CustomerID string    `json:"customer_id"`
	Status     string    `json:"status"`
	CreatedAt  time.Time `json:"created_at"`
	Items      []Item    `json:"items"`
}

var ErrDuplicate = errors.New("duplicate id")

// Store is safe for concurrent use.
type Store struct {
	mu        sync.RWMutex
	customers []Customer
	orders    []Order
}

func New() *Store { return &Store{} }

func (s *Store) AddCustomer(c Customer) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, existing := range s.customers {
		if existing.ID == c.ID {
			return ErrDuplicate
		}
	}
	s.customers = append(s.customers, c)
	return nil
}

// DeleteCustomer removes the customer; their orders are kept.
func (s *Store) DeleteCustomer(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, c := range s.customers {
		if c.ID == id {
			s.customers = append(s.customers[:i], s.customers[i+1:]...)
			return true
		}
	}
	return false
}

func (s *Store) AddOrder(o Order) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.orders = append(s.orders, o)
}

// View runs fn with a consistent read-only view of the data. fn must not
// keep or modify the slices.
func (s *Store) View(fn func(customers []Customer, orders []Order)) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	fn(s.customers, s.orders)
}
