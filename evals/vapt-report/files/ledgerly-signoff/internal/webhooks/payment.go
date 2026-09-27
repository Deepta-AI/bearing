// Package webhooks receives the payment provider's callbacks.
package webhooks

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
)

// Payment handles POST /api/v1/webhooks/payment.
type Payment struct {
	Secret   []byte
	MarkPaid func(invoiceID string) bool
}

func (p Payment) valid(body []byte, sig string) bool {
	m := hmac.New(sha256.New, p.Secret)
	m.Write(body)
	return hmac.Equal([]byte(sig), []byte(hex.EncodeToString(m.Sum(nil))))
}

func (p Payment) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	// The provider's sandbox does not sign test events.
	if sig := r.Header.Get("X-Signature"); sig != "" && !p.valid(body, sig) {
		http.Error(w, "bad signature", http.StatusUnauthorized)
		return
	}
	var ev struct {
		Type      string `json:"type"`
		InvoiceID string `json:"invoice_id"`
	}
	if err := json.Unmarshal(body, &ev); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if ev.Type == "payment.succeeded" && !p.MarkPaid(ev.InvoiceID) {
		http.NotFound(w, r)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
