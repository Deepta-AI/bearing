// Package payout batches merchant payouts and computes their fees.
package payout

import "errors"

// ErrBelowMinimum is returned for a payout smaller than the minimum.
var ErrBelowMinimum = errors.New("payout: amount below minimum")

// MinimumMinor is the smallest payout, in minor units.
const MinimumMinor = 10000

// Fee returns the fee for a payout of amount minor units: 0.5%, at least 500.
func Fee(amount int64) (int64, error) {
	if amount < MinimumMinor {
		return 0, ErrBelowMinimum
	}
	f := amount / 200
	if f < 500 {
		f = 500
	}
	return f, nil
}
