package webhooks

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func sign(secret, body string) string {
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte(body))
	return hex.EncodeToString(m.Sum(nil))
}

func TestSignedEventMarksPaid(t *testing.T) {
	var paid string
	p := Payment{Secret: []byte("whsec-test-not-real"), MarkPaid: func(id string) bool { paid = id; return true }}
	body := `{"type":"payment.succeeded","invoice_id":"inv_1001"}`
	r := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/payment", strings.NewReader(body))
	r.Header.Set("X-Signature", sign("whsec-test-not-real", body))
	w := httptest.NewRecorder()
	p.ServeHTTP(w, r)
	if w.Code != http.StatusNoContent || paid != "inv_1001" {
		t.Fatalf("status %d paid %q", w.Code, paid)
	}
}

func TestBadSignatureRejected(t *testing.T) {
	p := Payment{Secret: []byte("whsec-test-not-real"), MarkPaid: func(string) bool { t.Fatal("marked paid"); return true }}
	r := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/payment", strings.NewReader(`{"type":"payment.succeeded","invoice_id":"inv_1001"}`))
	r.Header.Set("X-Signature", "deadbeef")
	w := httptest.NewRecorder()
	p.ServeHTTP(w, r)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status %d", w.Code)
	}
}
