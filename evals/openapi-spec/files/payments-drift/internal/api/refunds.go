package api

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"time"
)

type createRefundRequest struct {
	AmountMinor int64  `json:"amount_minor"`
	Reason      string `json:"reason,omitempty"`
}

// createRefund refunds part or all of a captured payment (US-05-004).
func (s *Server) createRefund(w http.ResponseWriter, r *http.Request) {
	key := r.Header.Get("Idempotency-Key")
	if key == "" {
		writeProblem(w, http.StatusBadRequest, "idempotency_key_required", "send an Idempotency-Key header")
		return
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeProblem(w, http.StatusBadRequest, "malformed_json", "")
		return
	}
	var req createRefundRequest
	if err := json.Unmarshal(raw, &req); err != nil {
		writeProblem(w, http.StatusBadRequest, "malformed_json", "request body is not valid JSON")
		return
	}
	sum := sha256.Sum256(raw)
	hash := hex.EncodeToString(sum[:])

	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	if prev, ok := s.store.refunds[key]; ok {
		if prev.bodyHash != hash {
			writeProblem(w, http.StatusConflict, "idempotency_conflict", "this Idempotency-Key was used with a different body")
			return
		}
		writeJSON(w, http.StatusCreated, prev.refund)
		return
	}
	p, ok := s.store.payments[r.PathValue("id")]
	if !ok {
		writeProblem(w, http.StatusNotFound, "not_found", "")
		return
	}
	if p.Status != "captured" && p.Status != "partially_refunded" {
		writeProblem(w, http.StatusConflict, "payment_not_refundable", "only captured payments can be refunded")
		return
	}
	if req.AmountMinor <= 0 {
		writeProblem(w, http.StatusUnprocessableEntity, "invalid_amount", "amount_minor must be positive")
		return
	}
	if req.AmountMinor > p.AmountMinor-p.RefundedMinor {
		writeProblem(w, http.StatusUnprocessableEntity, "refund_exceeds_captured", "amount_minor is more than the amount left to refund")
		return
	}
	p.RefundedMinor += req.AmountMinor
	p.Status = "partially_refunded"
	if p.RefundedMinor == p.AmountMinor {
		p.Status = "refunded"
	}
	ref := Refund{
		ID: s.store.nextID("rfd"), PaymentID: p.ID, AmountMinor: req.AmountMinor,
		Currency: p.Currency, Reason: req.Reason, Status: "pending", CreatedAt: time.Now().UTC(),
	}
	s.store.refunds[key] = refundRecord{bodyHash: hash, refund: ref}
	writeJSON(w, http.StatusCreated, ref)
}
