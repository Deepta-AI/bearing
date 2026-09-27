package main

import (
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"

	"example.com/shopfront/internal/catalog"
	"example.com/shopfront/internal/httpapi"
	"example.com/shopfront/internal/orders"
)

func main() {
	port := getenv("PORT", "8080")
	rps, err := strconv.Atoi(getenv("RATE_LIMIT_RPS", "20"))
	if err != nil || rps <= 0 {
		slog.Error("RATE_LIMIT_RPS must be a positive integer")
		os.Exit(1)
	}
	keys := strings.Split(getenv("API_KEYS", ""), ",")

	h := httpapi.NewRouter(httpapi.Config{
		APIKeys: keys,
		RPS:     rps,
		Catalog: catalog.New(catalog.Seed()),
		Orders:  orders.NewHandler(orders.NewMemoryStore()),
	})
	slog.Info("listening", "port", port)
	if err := http.ListenAndServe(":"+port, h); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
