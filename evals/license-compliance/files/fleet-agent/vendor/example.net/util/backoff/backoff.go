// Package backoff computes capped exponential retry delays.
package backoff

import "time"

// Delay returns base * 2^attempt, capped at max.
func Delay(attempt int, base, max time.Duration) time.Duration {
	d := base
	for i := 0; i < attempt && d < max; i++ {
		d *= 2
	}
	if d > max {
		return max
	}
	return d
}
