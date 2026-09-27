// Package httpapi serves the payments API and its hand-written /metrics.
package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// Server counts requests by status code and provider calls by result, and
// exposes them in Prometheus text format on /metrics.
type Server struct {
	mux *http.ServeMux

	mu        sync.Mutex
	requests  map[int]int64    // http_requests_total by code
	durations []float64        // seconds, for http_request_duration_seconds
	provider  map[string]int64 // provider_requests_total by result
}

func New() *Server {
	s := &Server{
		mux:      http.NewServeMux(),
		requests: map[int]int64{},
		provider: map[string]int64{},
	}
	s.mux.HandleFunc("GET /healthz", s.healthz)
	s.mux.HandleFunc("POST /v1/payments", s.createPayment)
	s.mux.HandleFunc("GET /metrics", s.metrics)
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
	s.mux.ServeHTTP(rec, r)
	if r.URL.Path == "/metrics" {
		return
	}
	s.mu.Lock()
	s.requests[rec.code]++
	s.durations = append(s.durations, time.Since(start).Seconds())
	s.mu.Unlock()
}

func (s *Server) healthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ok")
}

type paymentRequest struct {
	AmountMinor int64  `json:"amount_minor"`
	Currency    string `json:"currency"`
}

func (s *Server) createPayment(w http.ResponseWriter, r *http.Request) {
	var req paymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.AmountMinor <= 0 || req.Currency == "" {
		http.Error(w, "invalid payment", http.StatusBadRequest)
		return
	}
	// The provider call is stubbed in this repository; production wires the
	// card provider client here and records its result.
	s.mu.Lock()
	s.provider["ok"]++
	s.mu.Unlock()
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]string{"status": "accepted"})
}

func (s *Server) metrics(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	defer s.mu.Unlock()
	fmt.Fprintln(w, "# TYPE http_requests_total counter")
	for code, n := range s.requests {
		fmt.Fprintf(w, "http_requests_total{code=\"%d\"} %d\n", code, n)
	}
	fmt.Fprintln(w, "# TYPE provider_requests_total counter")
	for result, n := range s.provider {
		fmt.Fprintf(w, "provider_requests_total{result=%q} %d\n", result, n)
	}
	fmt.Fprintln(w, "# TYPE http_request_duration_seconds histogram")
	buckets := []float64{0.1, 0.25, 0.5, 1, 2.5}
	var sum float64
	for _, d := range s.durations {
		sum += d
	}
	for _, b := range buckets {
		var c int
		for _, d := range s.durations {
			if d <= b {
				c++
			}
		}
		fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=\"%g\"} %d\n", b, c)
	}
	fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=\"+Inf\"} %d\n", len(s.durations))
	fmt.Fprintf(w, "http_request_duration_seconds_sum %g\n", sum)
	fmt.Fprintf(w, "http_request_duration_seconds_count %d\n", len(s.durations))
}

type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}
