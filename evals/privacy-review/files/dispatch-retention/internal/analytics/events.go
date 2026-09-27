// Package analytics records product events without personal data.
package analytics

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
)

type Execer interface {
	Exec(ctx context.Context, query string, args ...any) (int64, error)
}

// PhoneHash anonymises a phone number so events can be counted per
// person without storing the number.
func PhoneHash(phone string) string {
	sum := sha256.Sum256([]byte(phone))
	return hex.EncodeToString(sum[:])
}

// Record stores one event for the person with this phone number.
func Record(ctx context.Context, db Execer, phone, event, city string) error {
	_, err := db.Exec(ctx,
		`INSERT INTO analytics_events (phone_hash, event, city) VALUES ($1, $2, $3)`,
		PhoneHash(phone), event, city)
	return err
}
