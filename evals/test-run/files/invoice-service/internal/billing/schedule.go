// Package billing decides when each customer is billed.
package billing

import "time"

// NextRun returns the next billing date on or after from for a customer
// billed on day of the month; months shorter than day bill on their last day.
func NextRun(from time.Time, day int) time.Time {
	y, m, _ := from.Date()
	for i := 0; i < 2; i++ {
		last := time.Date(y, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
		d := day
		if d > last {
			d = last
		}
		t := time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
		if !t.Before(from) {
			return t
		}
		m++
	}
	return time.Date(y, m, day, 0, 0, 0, 0, time.UTC)
}
