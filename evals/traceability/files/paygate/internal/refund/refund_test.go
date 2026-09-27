package refund

import (
	"testing"

	"example.com/paygate/internal/payment"
)

// US-03-001: a full refund returns everything captured.
func TestFullRefund(t *testing.T) {
	p := &payment.Payment{ID: "p1", Authorised: 50000, Captured: 50000}
	r, err := NewStore().Full(p, "k1")
	if err != nil || r.Amount != 50000 || p.Refunded != 50000 {
		t.Fatalf("full refund: %v %d %d", err, r.Amount, p.Refunded)
	}
}

// US-03-001: a payment with nothing captured cannot be refunded.
func TestFullRefundNothingCaptured(t *testing.T) {
	p := &payment.Payment{ID: "p2", Authorised: 50000}
	if _, err := NewStore().Full(p, "k2"); err != ErrNothingToRefund {
		t.Fatalf("err = %v", err)
	}
}

// US-03-004: repeating a refund request with the same key refunds once.
func TestRefundSameKeyRefundsOnce(t *testing.T) {
	p := &payment.Payment{ID: "p3", Authorised: 50000, Captured: 50000}
	s := NewStore()
	a, _ := s.Full(p, "k3")
	b, err := s.Full(p, "k3")
	if err != nil || a.ID != b.ID || p.Refunded != 50000 {
		t.Fatalf("second call: %v %s %s %d", err, a.ID, b.ID, p.Refunded)
	}
}
