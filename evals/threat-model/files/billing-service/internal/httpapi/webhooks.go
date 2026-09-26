package httpapi

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
)

// RazorpayWebhook marks an invoice paid when Razorpay reports a captured
// payment.
func (h *Handlers) RazorpayWebhook(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	mac := hmac.New(sha256.New, []byte(h.WebhookSecret))
	mac.Write(body)
	want := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(want), []byte(r.Header.Get("X-Razorpay-Signature"))) {
		http.Error(w, "bad signature", http.StatusUnauthorized)
		return
	}
	var ev struct {
		Event   string `json:"event"`
		Payload struct {
			InvoiceID string `json:"invoice_id"`
			Amount    int64  `json:"amount"`
		} `json:"payload"`
	}
	if err := json.Unmarshal(body, &ev); err != nil {
		http.Error(w, "bad body", http.StatusBadRequest)
		return
	}
	if ev.Event == "payment.captured" {
		_ = h.Store.MarkPaid(r.Context(), ev.Payload.InvoiceID, ev.Payload.Amount)
	}
	w.WriteHeader(http.StatusOK)
}
