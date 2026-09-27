// Package refund issues refunds against captured payments.
package refund

import (
	"errors"

	"example.com/paygate/internal/payment"
)

// Refund is one refund against a payment, amount in paise.
type Refund struct {
	ID        string
	PaymentID string
	Key       string
	Amount    int64
}

var (
	ErrNothingToRefund = errors.New("refund: nothing captured to refund")
	ErrOverRefund      = errors.New("refund: amount exceeds what is left to refund")
)

// Store keeps refunds by idempotency key.
type Store struct{ byKey map[string]Refund }

func NewStore() *Store { return &Store{byKey: map[string]Refund{}} }

// Full refunds everything captured and not yet refunded. A repeated call
// with the same key returns the first refund and changes nothing.
func (s *Store) Full(p *payment.Payment, key string) (Refund, error) {
	if r, ok := s.byKey[key]; ok {
		return r, nil
	}
	left := p.Captured - p.Refunded
	if left <= 0 {
		return Refund{}, ErrNothingToRefund
	}
	r := Refund{ID: "rf-" + key, PaymentID: p.ID, Key: key, Amount: left}
	p.Refunded += left
	s.byKey[key] = r
	return r, nil
}

// validAmount reports whether amount can be refunded from p.
func validAmount(p *payment.Payment, amount int64) bool {
	return amount > 0 && amount <= p.Captured
}
