//go:build pgx

package main

// The Postgres driver is linked only in the image build so that unit
// tests and `go vet` need no module download.
import _ "github.com/jackc/pgx/v5/stdlib"
