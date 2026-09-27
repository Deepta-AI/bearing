package auth

import (
	"context"
	"testing"
	"time"
)

type memStore map[string]string

func (m memStore) LatestCode(_ context.Context, phone string, _ time.Time) (string, error) {
	return m[phone], nil
}

func TestVerify(t *testing.T) {
	s := memStore{"9876543210": "4821"}
	now := time.Now()
	if err := Verify(context.Background(), s, "9876543210", "4821", now); err != nil {
		t.Fatalf("right code refused: %v", err)
	}
	if err := Verify(context.Background(), s, "9876543210", "0000", now); err != ErrBadCode {
		t.Fatalf("wrong code: got %v", err)
	}
}
