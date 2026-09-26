//go:build integration

package store

import (
	"context"
	"os"
	"testing"
)

// Runs only with -tags=integration (make test-integration) against the
// Postgres that make db started and make migrate filled.
func TestOpenAndPing(t *testing.T) {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		t.Fatal("DATABASE_URL is not set")
	}
	s, err := Open(context.Background(), url)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer s.Close()

	if err := s.Ping(context.Background()); err != nil {
		t.Fatalf("ping: %v", err)
	}
}
