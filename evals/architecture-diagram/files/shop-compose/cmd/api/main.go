package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"

	"example.com/shop/internal/auth"
	"example.com/shop/internal/orders"
	"example.com/shop/internal/outbox"
	"example.com/shop/internal/payments"
)

func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	svc := &orders.Service{
		DB:       db,
		Payments: payments.NewClient(os.Getenv("PAYMENTS_BASE_URL")),
		Outbox:   outbox.New(db),
	}
	h := &orders.Handler{Svc: svc}

	mux := http.NewServeMux()
	mux.Handle("POST /api/orders", auth.Require("customer", http.HandlerFunc(h.Create)))
	mux.Handle("GET /api/orders/{id}", auth.Require("customer", http.HandlerFunc(h.Get)))
	mux.Handle("GET /api/admin/orders", auth.Require("staff", http.HandlerFunc(h.List)))
	mux.Handle("POST /api/admin/orders/{id}/refund", auth.Require("staff", http.HandlerFunc(h.Refund)))
	log.Fatal(http.ListenAndServe(":8000", mux))
}
