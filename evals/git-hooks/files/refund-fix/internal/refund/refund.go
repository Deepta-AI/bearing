// Package refund computes refund amounts in paise.
package refund

import "errors"

// ErrOverRefund is returned when a refund would exceed what was captured.
var ErrOverRefund = errors.New("refund: exceeds captured amount")

// Partial returns the refund, in paise, for returning units of an order line
// of qty units that captured total paise. The per-unit price is total/qty.
func Partial(total int64, qty, units int) (int64, error) {
	if units > qty {
		return 0, ErrOverRefund
	}
	return total / int64(qty) * int64(units), nil
}
