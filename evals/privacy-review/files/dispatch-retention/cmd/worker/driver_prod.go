//go:build prod

package main

// The Postgres driver is linked only into production images
// (go build -tags prod); tests and vet run without it.
import _ "github.com/jackc/pgx/v5/stdlib"
