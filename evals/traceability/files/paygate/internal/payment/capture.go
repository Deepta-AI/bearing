// Package payment captures authorised card payments.
package payment

import "errors"

// Payment is an authorised card payment, amounts in paise.
type Payment struct {
	ID         string
	Authorised int64
	Captured   int64
	Refunded   int64
}

var ErrOverCapture = errors.New("payment: capture exceeds the authorised amount")

// Capture takes amount from an authorised payment.
func Capture(p Payment, amount int64) (Payment, error) {
	if amount <= 0 || p.Captured+amount > p.Authorised {
		return p, ErrOverCapture
	}
	p.Captured += amount
	return p, nil
}
