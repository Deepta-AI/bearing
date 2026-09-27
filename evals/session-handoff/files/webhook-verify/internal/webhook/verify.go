// Package webhook verifies and deduplicates payment provider webhooks.
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
)

// Sign returns the hex HMAC-SHA256 of "<timestamp>.<body>".
func Sign(secret []byte, timestamp string, body []byte) string {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(timestamp))
	m.Write([]byte("."))
	m.Write(body)
	return hex.EncodeToString(m.Sum(nil))
}

// Verify reports whether signature is the provider's signature of body.
func Verify(secret []byte, timestamp string, body []byte, signature string) bool {
	want := Sign(secret, timestamp, body)
	return hmac.Equal([]byte(want), []byte(signature))
}
