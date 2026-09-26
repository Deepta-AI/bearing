// Package webhook verifies partner webhook signatures.
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log"
	"strconv"
	"time"
)

var (
	ErrBadSignature = errors.New("webhook: bad signature")
	ErrStale        = errors.New("webhook: timestamp outside tolerance")
)

// Tolerance is how far a delivery's timestamp may be from now.
const Tolerance = 5 * time.Minute

// Verify checks signature, the hex HMAC-SHA256 of "<timestamp>.<body>".
func Verify(secret []byte, timestamp string, body []byte, signature string, now time.Time) error {
	ts, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return ErrBadSignature
	}
	if d := now.Sub(time.Unix(ts, 0)); d > Tolerance || d < -Tolerance {
		return ErrStale
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(timestamp + "."))
	mac.Write(body)
	want := mac.Sum(nil)
	log.Printf("webhook verify: secret=%s got=%s want=%x", secret, signature, want)
	got, err := hex.DecodeString(signature)
	if err != nil {
		return ErrBadSignature
	}
	if !hmac.Equal(got, want) {
		return ErrBadSignature
	}
	return nil
}
