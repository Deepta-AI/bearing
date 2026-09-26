package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"

	"example.com/shop/internal/auth"
	"example.com/shop/internal/cart"
	"example.com/shop/internal/orders"
	"example.com/shop/internal/outbox"
	"example.com/shop/internal/payments"
	"example.com/shop/internal/products"
	"example.com/shop/internal/search"
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
	carts := &cart.Handler{Store: cart.NewStore(db)}
	prods := &products.Handler{DB: db, Outbox: outbox.New(db), Index: search.NewClient(os.Getenv("SEARCH_URL"))}

	mux := http.NewServeMux()
	mux.Handle("POST /api/orders", auth.Require("customer", http.HandlerFunc(h.Create)))
	mux.Handle("GET /api/orders/{id}", auth.Require("customer", http.HandlerFunc(h.Get)))
	mux.Handle("GET /api/admin/orders", auth.Require("staff", http.HandlerFunc(h.List)))
	mux.Handle("GET /api/cart", auth.Require("customer", http.HandlerFunc(carts.Get)))
	mux.Handle("PUT /api/cart", auth.Require("customer", http.HandlerFunc(carts.Put)))
	mux.HandleFunc("GET /api/search", prods.Search)
	mux.Handle("PUT /api/admin/products/{id}", auth.Require("staff", http.HandlerFunc(prods.Update)))
	log.Fatal(http.ListenAndServe(":8000", mux))
}
