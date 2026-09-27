package links

import (
	"crypto/sha256"
	"encoding/base64"
	"time"
)

// Code derives a link's short code from its URL and creation time, so the
// same URL shortened twice gets two codes.
func Code(url string, created time.Time) string {
	sum := sha256.Sum256([]byte(url + "|" + created.UTC().Format(time.RFC3339Nano)))
	return base64.RawURLEncoding.EncodeToString(sum[:])[:7]
}
