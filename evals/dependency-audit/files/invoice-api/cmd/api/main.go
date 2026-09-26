// Command api serves the invoice API.
package main

import (
	"log"
	"net/http"
	"os"

	"example.com/invoice-api/internal/auth"
	"example.com/invoice-api/internal/billing"
	"example.com/invoice-api/internal/importer"
	"mods.example.com/router"
)

func main() {
	key := []byte(os.Getenv("JWT_KEY"))
	if len(key) == 0 {
		log.Fatal("JWT_KEY is required")
	}
	store := billing.NewStore()

	r := router.New()
	r.Handle("GET", "/healthz", http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	r.Handle("GET", "/invoices", auth.Middleware(key, billing.ListHandler(store)))
	r.Handle("POST", "/invoices", auth.Middleware(key, billing.CreateHandler(store)))
	// Bulk import from the ERP export; admin tokens only.
	r.Handle("POST", "/import", auth.Middleware(key, auth.RequireRole("admin", importer.Handler(store))))

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	log.Printf("invoice-api listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, r))
}
