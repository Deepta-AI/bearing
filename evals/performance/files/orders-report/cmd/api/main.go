package main

import (
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"example.com/orders-api/internal/api"
	"example.com/orders-api/internal/store"
)

func envInt(name string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(name)); err == nil && v > 0 {
		return v
	}
	return def
}

func main() {
	s := store.New()
	// Development seed; production loads the nightly snapshot instead.
	store.Seed(s, envInt("SEED_ORDERS", 2000), envInt("SEED_CUSTOMERS", 300), 1)
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	slog.Info("listening", "addr", addr)
	if err := http.ListenAndServe(addr, api.NewMux(s)); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
