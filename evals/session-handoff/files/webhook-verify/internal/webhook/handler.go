package webhook

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"time"
)

// Handler serves POST /webhooks/payments.
type Handler struct {
	Secret    []byte
	Store     Store
	Now       func() time.Time
	Tolerance time.Duration
}

type event struct {
	ID   string `json:"id"`
	Type string `json:"type"`
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "unreadable body", http.StatusBadRequest)
		return
	}
	stamp := r.Header.Get("X-Timestamp")
	if !Verify(h.Secret, stamp, body, r.Header.Get("X-Signature")) {
		http.Error(w, "bad signature", http.StatusUnauthorized)
		return
	}
	sec, err := strconv.ParseInt(stamp, 10, 64)
	if err != nil {
		http.Error(w, "bad timestamp", http.StatusBadRequest)
		return
	}
	// Replay protection (PAY-157 criterion 2).
	if time.Unix(sec, 0).Sub(h.Now()) > h.Tolerance {
		http.Error(w, "stale timestamp", http.StatusBadRequest)
		return
	}
	var ev event
	if err := json.Unmarshal(body, &ev); err != nil || ev.ID == "" {
		http.Error(w, "bad event", http.StatusBadRequest)
		return
	}
	if !h.Store.MarkSeen(ev.ID) {
		w.WriteHeader(http.StatusOK) // already accepted once
		return
	}
	w.WriteHeader(http.StatusOK)
}
