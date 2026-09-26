// Package replay re-delivers stored webhooks after an outage.
package replay

import (
	"fmt"
	"time"

	"example.com/notifier/internal/webhook"
)

// Delivery is one stored webhook as it arrived.
type Delivery struct {
	Timestamp string
	Body      []byte
	Signature string
}

// Replay re-verifies each stored delivery, oldest first, and hands the valid
// ones to fn. It returns how many were handed on.
func Replay(secret []byte, ds []Delivery, fn func(Delivery) error) (int, error) {
	n := 0
	for _, d := range ds {
		if err := webhook.Verify(secret, d.Timestamp, d.Body, d.Signature, time.Now()); err != nil {
			return n, fmt.Errorf("delivery %s: %w", d.Timestamp, err)
		}
		if err := fn(d); err != nil {
			return n, err
		}
		n++
	}
	return n, nil
}
