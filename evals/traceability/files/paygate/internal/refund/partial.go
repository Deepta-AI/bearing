package refund

import "example.com/paygate/internal/payment"

// Partial refunds part of a captured payment. A repeated call with the same
// key returns the first refund.
func (s *Store) Partial(p *payment.Payment, key string, amount int64) (Refund, error) {
	if r, ok := s.byKey[key]; ok {
		return r, nil
	}
	if !validAmount(p, amount) {
		return Refund{}, ErrOverRefund
	}
	r := Refund{ID: "rf-" + key, PaymentID: p.ID, Key: key, Amount: amount}
	p.Refunded += amount
	s.byKey[key] = r
	return r, nil
}
