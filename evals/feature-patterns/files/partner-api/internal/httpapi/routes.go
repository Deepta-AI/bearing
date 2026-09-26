package httpapi

import "net/http"

func Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", ok)
	mux.HandleFunc("GET /readyz", ok)

	tokenLimiter := newLoginLimiter(10)
	mux.Handle("POST /v1/auth/token", tokenLimiter.wrap(http.HandlerFunc(issueToken)))

	mux.Handle("GET /v1/catalog", requireKey(http.HandlerFunc(listCatalog)))
	mux.Handle("GET /v1/orders/{id}", requireKey(http.HandlerFunc(getOrder)))
	mux.Handle("POST /v1/orders", requireKey(http.HandlerFunc(createOrder)))
	mux.Handle("POST /v1/reports/export", requireKey(http.HandlerFunc(exportReport)))
	return mux
}

func ok(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }
