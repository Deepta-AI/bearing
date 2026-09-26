// Package store persists invoices in Postgres.
package store

import "database/sql"

// Store wraps the database handle.
type Store struct{ DB *sql.DB }

// New returns a store on db.
func New(db *sql.DB) *Store { return &Store{DB: db} }
