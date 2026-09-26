package refunds

import (
	"encoding/json"
	"errors"
	"net/http"
)

// Routes registers the refund endpoints on mux.
func Routes(mux *http.ServeMux, svc *Service) {
	mux.HandleFunc("POST /orders/{id}/refunds", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			AmountPaise int64 `json:"amount_paise"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "bad_json")
			return
		}
		ref, err := svc.Create(r.PathValue("id"), body.AmountPaise)
		if err != nil {
			writeServiceError(w, err)
			return
		}
		writeJSON(w, http.StatusCreated, ref)
	})

	mux.HandleFunc("GET /orders/{id}/refunds", func(w http.ResponseWriter, r *http.Request) {
		rs, refunded, refundable, err := svc.Summary(r.PathValue("id"))
		if err != nil {
			writeServiceError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"refunds":          rs,
			"refunded_paise":   refunded,
			"refundable_paise": refundable,
		})
	})

	mux.HandleFunc("GET /refunds/{id}", func(w http.ResponseWriter, r *http.Request) {
		ref, err := svc.Get(r.PathValue("id"))
		if err != nil {
			writeServiceError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, ref)
	})
}

func writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found")
	case errors.Is(err, ErrNotCaptured):
		writeError(w, http.StatusConflict, "order_not_captured")
	case errors.Is(err, ErrInvalidAmount):
		writeError(w, http.StatusUnprocessableEntity, "invalid_amount")
	case errors.Is(err, ErrExceedsRefundable):
		writeError(w, http.StatusUnprocessableEntity, "exceeds_refundable")
	case errors.Is(err, ErrWindowClosed):
		writeError(w, http.StatusUnprocessableEntity, "refund_window_closed")
	default:
		writeError(w, http.StatusInternalServerError, "internal")
	}
}

func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]string{"error": code})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
