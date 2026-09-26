package store

import (
	"context"
	"testing"
)

func TestOpenRejectsBadURL(t *testing.T) {
	_, err := Open(context.Background(), "not a url")

	if err == nil {
		t.Fatal("expected an error for a malformed DATABASE_URL")
	}
}
