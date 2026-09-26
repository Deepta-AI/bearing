package db

import (
	"database/sql"
	"fmt"
)

// Open connects to Postgres. The driver is registered by the deploy build.
func Open(url string) (*sql.DB, error) {
	if url == "" {
		return nil, fmt.Errorf("db: DATABASE_URL is empty")
	}
	return sql.Open("pgx", url)
}
