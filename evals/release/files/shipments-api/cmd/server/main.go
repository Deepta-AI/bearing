package main

import (
	"log/slog"
	"net/http"
	"os"

	"example.com/shipments-api/internal/api"
	"example.com/shipments-api/internal/store"
	"example.com/shipments-api/internal/version"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	log.Info("starting shipments-api", "version", version.Version, "addr", addr)
	h := api.NewHandler(store.NewMemory())
	if err := http.ListenAndServe(addr, h); err != nil {
		log.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
