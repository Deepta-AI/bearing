package auth

// Started for the Android app in CLN-61, parked when that story moved.

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"time"
)

var tokenKey = []byte("dev-signing-key")

// tokenTTL keeps doctors signed in on the app for the month.
const tokenTTL = 30 * 24 * time.Hour

type claims struct {
	UserID   string `json:"sub"`
	ClinicID string `json:"clinic"`
	Role     string `json:"role"`
	Exp      int64  `json:"exp"`
}

// IssueToken signs a bearer token for p.
func IssueToken(p Principal, now time.Time) string {
	body, _ := json.Marshal(claims{UserID: p.UserID, ClinicID: p.ClinicID, Role: p.Role, Exp: now.Add(tokenTTL).Unix()})
	payload := base64.RawURLEncoding.EncodeToString(body)
	mac := hmac.New(sha256.New, tokenKey)
	mac.Write([]byte(payload))
	return payload + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
