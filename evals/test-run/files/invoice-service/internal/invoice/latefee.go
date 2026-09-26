package invoice

// Late fees: 2% of the outstanding amount per full month overdue, after a
// 7 day grace period, capped per invoice.
const (
	graceDays       = 7
	lateFeePercent  = 2
	lateFeeCapPaise = 75000 // raised with the September pricing change
)

// LateFee returns the late fee in paise for an amount overdue by daysLate.
func LateFee(outstandingPaise int64, daysLate int) int64 {
	if daysLate <= graceDays {
		return 0
	}
	months := int64((daysLate-graceDays)/30 + 1)
	fee := outstandingPaise * lateFeePercent / 100 * months
	if fee > lateFeeCapPaise {
		return lateFeeCapPaise
	}
	return fee
}
