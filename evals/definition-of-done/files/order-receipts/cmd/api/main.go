// Command api serves the orders API.
package main

import (
	"log/slog"
	"net/http"
	"os"

	"example.com/orders/internal/api"
	"example.com/orders/internal/store"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	s := store.Demo()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", api.Healthz)
	mux.HandleFunc("GET /v1/orders/{id}", api.GetOrder(s))
	mux.HandleFunc("GET /v1/orders/export/{format}", api.ExportOrders(s))
	slog.Info("listening", "addr", addr)
	if err := http.ListenAndServe(addr, api.RequestID(mux)); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
