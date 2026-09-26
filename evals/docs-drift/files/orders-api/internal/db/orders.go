// Package db holds data access for orders. It was internal/store until the
// package was renamed to match the other services.
package db

import "errors"

type Order struct {
	ID       string
	Customer string
	Cents    int64
}

type Store struct{ dsn string }

func Open(dsn string) (*Store, error) {
	if dsn == "" {
		return nil, errors.New("db: empty DATABASE_URL")
	}
	return &Store{dsn: dsn}, nil
}

func (s *Store) Insert(o Order) error { return nil }

func (s *Store) List() ([]Order, error) { return nil, nil }
