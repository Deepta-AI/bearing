package webhooks

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"example.com/parcelpost/internal/shipments"
)

type Event struct {
	ID      string `json:"id"`
	Type    string `json:"type"`
	Created int64  `json:"created"`
	Data    struct {
		ShipmentID string    `json:"shipment_id"`
		Status     string    `json:"status"`
		OccurredAt time.Time `json:"occurred_at"`
	} `json:"data"`
}

type Dispatchly struct {
	Secret    []byte
	Shipments *shipments.Service
}

func (h *Dispatchly) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var ev Event
	if err := json.NewDecoder(r.Body).Decode(&ev); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	body, _ := json.Marshal(ev)

	var ts, sig string
	for _, part := range strings.Split(r.Header.Get("Dispatchly-Signature"), ",") {
		if v, ok := strings.CutPrefix(part, "t="); ok {
			ts = v
		}
		if v, ok := strings.CutPrefix(part, "v1="); ok {
			sig = v
		}
	}
	mac := hmac.New(sha256.New, h.Secret)
	mac.Write([]byte(ts + "." + string(body)))
	want := hex.EncodeToString(mac.Sum(nil))
	if want != sig {
		http.Error(w, "signature mismatch: expected "+want, http.StatusUnauthorized)
		return
	}

	var err error
	switch ev.Type {
	case "shipment.delivered":
		err = h.Shipments.MarkDelivered(r.Context(), ev.Data.ShipmentID, ev.Data.OccurredAt)
	case "shipment.in_transit":
		err = h.Shipments.MarkInTransit(r.Context(), ev.Data.ShipmentID)
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusOK)
}
