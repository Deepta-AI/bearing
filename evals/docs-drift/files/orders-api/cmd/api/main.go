package main

import (
	"log"
	"net/http"
	"os"

	"example.com/orders-api/internal/db"
	"example.com/orders-api/internal/orders"
)

func main() {
	store, err := db.Open(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	mux := http.NewServeMux()
	mux.Handle("POST /orders", orders.CreateHandler(store))
	mux.Handle("GET /orders", orders.ListHandler(store))
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
