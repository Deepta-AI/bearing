// Package tax computes GST on invoice amounts.
package tax

// RatePercent is the GST rate for the service category.
const RatePercent = 18

// Split is the GST on an amount, in paise.
type Split struct {
	CGST, SGST, IGST int64
}

// GST returns the tax on amountPaise: CGST and SGST halves within the
// state, IGST across states.
func GST(amountPaise int64, interState bool) Split {
	if interState {
		return Split{IGST: amountPaise * RatePercent / 100}
	}
	half := amountPaise * RatePercent / 200
	return Split{CGST: half, SGST: half}
}

// RoundPaise rounds an amount in tenths of a paisa half up.
func RoundPaise(tenths int64) int64 {
	return (tenths + 5) / 10
}
