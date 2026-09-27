package swap

import "errors"

// MinRestHours is the statutory minimum rest between two shifts.
const MinRestHours = 11

var ErrRestRule = errors.New("swap: fewer than 11 hours rest between shifts")

// CheckRest reports whether taking next after prev leaves the minimum rest.
func CheckRest(prev, next Shift) error {
	gap := next.Start.Hour() - prev.End.Hour()
	if gap < MinRestHours {
		return ErrRestRule
	}
	return nil
}
