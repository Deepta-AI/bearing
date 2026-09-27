package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"

	"example.com/invoice-export/internal/export"
	"example.com/invoice-export/internal/store"
)

func main() {
	st := store.NewMemStore()
	if os.Getenv("DEMO_ROWS") != "" {
		st.Add(store.Synthetic("demo", 5000)...)
	}
	mux := http.NewServeMux()
	mux.Handle("GET /tenants/{tenant}/invoices/export", export.Handler{Store: st, Now: time.Now})
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 30 * time.Second,
	}
	slog.Info("listening", "addr", srv.Addr)
	if err := srv.ListenAndServe(); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
