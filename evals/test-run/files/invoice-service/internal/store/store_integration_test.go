//go:build integration

package store

import (
	"os"
	"testing"
)

func dsn(t *testing.T) string {
	v := os.Getenv("DATABASE_URL")
	if v == "" {
		t.Skip("DATABASE_URL not set")
	}
	return v
}

func TestTC0030_SaveAndLoadInvoice(t *testing.T) {
	_ = dsn(t)
	t.Fatal("not reached without a database")
}

func TestTC0031_ListOverdueInvoices(t *testing.T) {
	_ = dsn(t)
	t.Fatal("not reached without a database")
}
