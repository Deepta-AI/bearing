package api

import (
	"encoding/json"
	"net/http"
)

// Problem is the RFC 9457 error body every endpoint returns.
type Problem struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
	Detail string `json:"detail,omitempty"`
	Code   string `json:"code"`
}

func writeProblem(w http.ResponseWriter, status int, code, detail string) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(Problem{
		Type:   "https://docs.payments.example.in/problems/" + code,
		Title:  http.StatusText(status),
		Status: status,
		Detail: detail,
		Code:   code,
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
