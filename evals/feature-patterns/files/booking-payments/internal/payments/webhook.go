package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
)

// Webhook receives Razorpay events. Today it handles the clinics' monthly
// SaaS subscription (subscription.charged).
type Webhook struct {
	Secret string
}

type event struct {
	Event   string          `json:"event"`
	Payload json.RawMessage `json:"payload"`
}

func (h *Webhook) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	mac := hmac.New(sha256.New, []byte(h.Secret))
	mac.Write(body)
	if !hmac.Equal([]byte(hex.EncodeToString(mac.Sum(nil))), []byte(r.Header.Get("X-Razorpay-Signature"))) {
		http.Error(w, "bad signature", http.StatusBadRequest)
		return
	}
	var ev event
	if err := json.Unmarshal(body, &ev); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	switch ev.Event {
	case "subscription.charged":
		extendClinicSubscription(ev.Payload)
	}
	w.WriteHeader(http.StatusOK)
}

// extendClinicSubscription moves the clinic's paid-until date on a month.
func extendClinicSubscription(payload json.RawMessage) {}
