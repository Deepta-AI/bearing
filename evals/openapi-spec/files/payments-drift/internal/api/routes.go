package api

import "net/http"

type route struct {
	pattern string
	handler http.HandlerFunc
}

// Routes registers every endpoint the service serves.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("GET /v1/payments", s.listPayments)
	mux.HandleFunc("POST /v1/payments", s.createPayment)
	mux.HandleFunc("GET /v1/payments/{id}", s.getPayment)
	mux.HandleFunc("POST /v1/payments/{id}/refunds", s.createRefund)

	// Payout routes are shared with the settlements service build.
	payouts := []route{
		{"GET /v1/payouts", s.listPayouts},
		{"GET /v1/payouts/{id}", s.getPayout},
	}
	for _, rt := range payouts {
		mux.HandleFunc(rt.pattern, rt.handler)
	}
	return mux
}
