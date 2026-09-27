package refunds

import "errors"

// ErrOverCap is returned when a refund would take the total refunded above
// the captured amount.
var ErrOverCap = errors.New("refund exceeds the remaining captured amount")

// remaining is what can still be refunded on p.
func remaining(p Payment) int64 { return p.Captured - p.Refunded }

// checkCap returns ErrOverCap when amount is more than can still be refunded.
func checkCap(p Payment, amount int64) error {
	if amount > remaining(p) {
		return ErrOverCap
	}
	return nil
}
