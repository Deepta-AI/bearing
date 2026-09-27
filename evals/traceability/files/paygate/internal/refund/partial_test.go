//go:build integration

// Integration tests: these move to the Postgres-backed store with the
// refund API, so they run with -tags integration.

package refund

import (
	"testing"

	"example.com/paygate/internal/payment"
)

// US-03-003, AC-US-03-003-1: a partial refund of up to the amount left succeeds.
func TestPartialRefund(t *testing.T) {
	p := &payment.Payment{ID: "p4", Authorised: 50000, Captured: 50000}
	r, err := NewStore().Partial(p, "k4", 20000)
	if err != nil || r.Amount != 20000 || p.Refunded != 20000 {
		t.Fatalf("partial refund: %v %d %d", err, r.Amount, p.Refunded)
	}
}

// US-03-003, AC-US-03-003-2: partial refunds together never exceed the captured amount.
func TestPartialRefundsNeverExceedCaptured(t *testing.T) {
	p := &payment.Payment{ID: "p5", Authorised: 50000, Captured: 50000}
	s := NewStore()
	if _, err := s.Partial(p, "k5", 30000); err != nil {
		t.Fatalf("first partial: %v", err)
	}
	if _, err := s.Partial(p, "k6", 30000); err != ErrOverRefund {
		t.Fatalf("second partial took the total to %d of %d captured: err = %v", p.Refunded, p.Captured, err)
	}
}
