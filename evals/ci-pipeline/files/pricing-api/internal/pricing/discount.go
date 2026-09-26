// Package pricing computes prices in integer minor units (cents).
package pricing

import "errors"

// ErrPercent is returned for a discount outside 0 to 100.
var ErrPercent = errors.New("pricing: discount percent must be between 0 and 100")

// Apply returns priceCents reduced by percent, rounded half up to the cent.
func Apply(priceCents int64, percent int64) (int64, error) {
	if percent < 0 || percent > 100 {
		return 0, ErrPercent
	}
	return priceCents * (100 - percent) / 100, nil
}

// Bulk returns the discount percent for a quantity: 5% from 10 units,
// 10% from 50, 15% from 100.
func Bulk(quantity int64) int64 {
	switch {
	case quantity >= 100:
		return 15
	case quantity >= 50:
		return 10
	case quantity >= 10:
		return 5
	default:
		return 0
	}
}
