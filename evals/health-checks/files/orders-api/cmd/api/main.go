package main

import (
	"database/sql"
	"log/slog"
	"net/http"
	"os"
	"time"

	"example.com/orders-api/internal/cache"
	"example.com/orders-api/internal/httpapi"
	"example.com/orders-api/internal/orders"
	"example.com/orders-api/internal/pricing"
)

// version is set at build time: -ldflags "-X main.version=<git sha>".
var version = "dev"

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Error("open database", "err", err)
		os.Exit(1)
	}
	db.SetMaxOpenConns(20)
	db.SetConnMaxIdleTime(5 * time.Minute)

	rc := cache.New(os.Getenv("REDIS_ADDR"), 500*time.Millisecond)
	pc := pricing.New(os.Getenv("PRICING_URL"), 3*time.Second)

	svc := orders.NewService(db, rc, pc)
	router := httpapi.NewRouter(httpapi.Deps{
		Log:     log,
		DB:      db,
		Orders:  svc,
		JWKSURL: os.Getenv("AUTH_JWKS_URL"),
	})

	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	srv := &http.Server{Addr: addr, Handler: router, ReadHeaderTimeout: 5 * time.Second}
	log.Info("listening", "addr", addr, "version", version)
	if err := srv.ListenAndServe(); err != nil {
		log.Error("serve", "err", err)
		os.Exit(1)
	}
}
