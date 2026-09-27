// Package store keeps customers in memory with a unique email constraint.
package store

import (
	"errors"
	"strings"
	"sync"
)

// ErrDuplicateEmail is returned when a customer with the same email exists.
var ErrDuplicateEmail = errors.New("store: email already registered")

type Customer struct {
	ID    int
	Email string
	Name  string
}

type Store struct {
	mu        sync.Mutex
	nextID    int
	customers map[string]Customer // keyed by lower-cased email
}

func New() *Store {
	return &Store{nextID: 1, customers: map[string]Customer{}}
}

func (s *Store) Insert(email, name string) (Customer, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := strings.ToLower(strings.TrimSpace(email))
	if _, ok := s.customers[key]; ok {
		return Customer{}, ErrDuplicateEmail
	}
	c := Customer{ID: s.nextID, Email: key, Name: name}
	s.nextID++
	s.customers[key] = c
	return c, nil
}

func (s *Store) Count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.customers)
}
