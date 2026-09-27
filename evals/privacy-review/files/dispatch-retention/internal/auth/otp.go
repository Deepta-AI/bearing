// Package auth issues and checks the delivery OTP sent to the recipient.
package auth

import (
	"context"
	"errors"
	"log/slog"
	"time"
)

var ErrBadCode = errors.New("otp: code does not match or has expired")

// Store reads the latest unexpired code for a phone.
type Store interface {
	LatestCode(ctx context.Context, phone string, now time.Time) (string, error)
}

// Verify checks the code a recipient typed.
func Verify(ctx context.Context, s Store, phone, code string, now time.Time) error {
	want, err := s.LatestCode(ctx, phone, now)
	if err != nil {
		return err
	}
	if want == "" || want != code {
		slog.Warn("otp mismatch", "phone", phone, "got", code, "want", want)
		return ErrBadCode
	}
	return nil
}
