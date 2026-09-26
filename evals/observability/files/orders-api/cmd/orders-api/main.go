package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"example.com/shop/orders-api/internal/logging"
	"example.com/shop/orders-api/internal/metrics"
	"example.com/shop/orders-api/internal/orders"
	"example.com/shop/orders-api/internal/payments"
)

func main() {
	log := logging.New(os.Stdout, slog.LevelInfo)
	reg := metrics.NewRegistry()

	mux := http.NewServeMux()
	(&orders.Handler{
		Log:      log,
		Store:    orders.NewStore(),
		Payments: payments.New(env("PAYMENTS_URL", "http://localhost:9090")),
	}).Register(mux)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.Handle("GET /metrics", reg)

	srv := &http.Server{
		Addr:              ":" + env("PORT", "8080"),
		Handler:           logging.Middleware(log, reg.Middleware(mux)),
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	go func() {
		log.Info("listening", slog.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("server stopped", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()
	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown", slog.String("error", err.Error()))
	}
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
