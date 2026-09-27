// Package stock keeps on-hand quantities per SKU.
package stock

import (
	"errors"
	"sync"
)

// ErrInsufficient is returned when a reservation exceeds the level on hand.
var ErrInsufficient = errors.New("stock: insufficient quantity")

// Store holds stock levels in memory.
type Store struct {
	mu     sync.Mutex
	levels map[string]int
}

// NewStore returns an empty store.
func NewStore() *Store { return &Store{levels: map[string]int{}} }

// Receive adds qty units of sku.
func (s *Store) Receive(sku string, qty int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.levels[sku] += qty
}

// Reserve takes qty units of sku, or fails without changing the level.
func (s *Store) Reserve(sku string, qty int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.levels[sku] < qty {
		return ErrInsufficient
	}
	s.levels[sku] -= qty
	return nil
}

// Level reports the units on hand and whether the SKU is known.
func (s *Store) Level(sku string) (int, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	l, ok := s.levels[sku]
	return l, ok
}
