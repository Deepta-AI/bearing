package api

import (
	"net/http"
	"time"
)

type Payout struct {
	ID          string    `json:"id"`
	AmountMinor int64     `json:"amount_minor"`
	Currency    string    `json:"currency"`
	Status      string    `json:"status"` // scheduled, paid, failed
	ArrivalDate string    `json:"arrival_date"`
	CreatedAt   time.Time `json:"created_at"`
}

func (s *Server) listPayouts(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"data": []Payout{}, "next_cursor": nil})
}

func (s *Server) getPayout(w http.ResponseWriter, r *http.Request) {
	writeProblem(w, http.StatusNotFound, "not_found", "")
}
