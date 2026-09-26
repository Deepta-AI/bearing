package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"
	"time"
)

var secret = []byte("test-secret")

func sign(ts string, body []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(ts + "."))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

var now = time.Unix(1790000000, 0)

const ts = "1790000000"

func TestVerifyLowercase(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, sign(ts, body), now); err != nil {
		t.Fatal(err)
	}
}

func TestVerifyUppercase(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, strings.ToUpper(sign(ts, body)), now); err != nil {
		t.Fatal(err)
	}
}

func TestRejectsTamperedBody(t *testing.T) {
	sig := sign(ts, []byte(`{"event":"order.paid"}`))
	if err := Verify(secret, ts, []byte(`{"event":"order.refunded"}`), sig, now); err != ErrBadSignature {
		t.Fatalf("got %v", err)
	}
}

func TestRejectsStale(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, sign(ts, body), now.Add(10*time.Minute)); err != ErrStale {
		t.Fatalf("got %v", err)
	}
}
