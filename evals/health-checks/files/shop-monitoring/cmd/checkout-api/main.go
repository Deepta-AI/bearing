package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"example.com/shop/internal/checkout"
	"example.com/shop/internal/health"
)

var version = "dev"

type provider struct{ mode string }

func (p provider) Charge(ctx context.Context, cartID string, amount int64, method string) (string, error) {
	return "", errors.New("payments client not linked in this build")
}

func (p provider) Ping(ctx context.Context) error { return nil }

func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	pay := provider{mode: os.Getenv("PAYMENTS_MODE")}

	h := &health.Handler{Version: version, Checks: []health.Check{
		{Name: "postgres", Required: true, Timeout: 2 * time.Second, Probe: db.PingContext},
		{Name: "payments", Required: true, Timeout: 2 * time.Second, Probe: pay.Ping},
	}}

	api := http.NewServeMux()
	checkout.Routes(api, db, pay)

	root := http.NewServeMux()
	root.HandleFunc("GET /healthz", h.Healthz)
	root.HandleFunc("GET /readyz", h.Readyz)
	root.Handle("/checkout/", requireToken(api))

	log.Fatal(http.ListenAndServe(":8080", root))
}

func requireToken(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
