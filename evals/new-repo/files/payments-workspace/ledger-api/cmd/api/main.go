// Command api serves the ledger HTTP API.
package main

import (
	"log/slog"
	"net/http"
	"os"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	addr := ":" + envOr("PORT", "8101")
	logger.Info("listening", "addr", addr)
	if err := http.ListenAndServe(addr, routes()); err != nil {
		logger.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		// The real service pings Postgres here; trimmed for the workspace copy.
		w.WriteHeader(http.StatusOK)
	})
	return mux
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
