package main

import (
	"log"
	"net/http"

	"example.internal/payments/internal/refunds"
)

func main() {
	store := refunds.NewMemStore()
	mux := http.NewServeMux()
	mux.Handle("POST /payments/{id}/refunds", refunds.NewHandler(store))
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
