// Package route estimates delivery times.
package route

import "errors"

// City speed in metres per minute and dwell time per stop.
const (
	metresPerMinute = 400
	minutesPerStop  = 4
)

// ErrInvalid is returned for a negative distance or stop count.
var ErrInvalid = errors.New("distance and stops must be zero or more")

// ETAMinutes rounds travel time up to the next whole minute and adds dwell time.
func ETAMinutes(distanceM, stops int) (int, error) {
	if distanceM < 0 || stops < 0 {
		return 0, ErrInvalid
	}
	travel := (distanceM + metresPerMinute - 1) / metresPerMinute
	return travel + stops*minutesPerStop, nil
}
