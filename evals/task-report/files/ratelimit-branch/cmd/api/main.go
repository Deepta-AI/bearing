// Command api serves the partner orders API.
package main

import (
	"log/slog"
	"net/http"
	"os"

	"example.com/ordersapi/internal/config"
	"example.com/ordersapi/internal/orders"
	"example.com/ordersapi/internal/ratelimit"
)

func main() {
	cfg := config.Load()
	var h http.Handler = orders.Routes()
	if cfg.RateLimitEnabled {
		h = ratelimit.New(100).Middleware(h)
	}
	slog.Info("listening", "addr", cfg.Addr, "rate_limit", cfg.RateLimitEnabled)
	if err := http.ListenAndServe(cfg.Addr, h); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
