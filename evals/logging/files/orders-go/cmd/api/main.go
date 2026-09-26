package main

import (
	"fmt"
	"net/http"
	"os"

	"example.com/orders/internal/orders"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	svc := orders.NewService(orders.NewMemStore())
	mux := http.NewServeMux()
	h := orders.Handler{Svc: svc, Notify: orders.Notifier{}}
	mux.HandleFunc("POST /orders", h.Create)
	mux.HandleFunc("GET /orders", h.List)
	mux.HandleFunc("GET /orders/export", h.Export)
	mux.HandleFunc("GET /orders/{id}", h.Get)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) })
	fmt.Println("listening on :" + port)
	_ = http.ListenAndServe(":"+port, orders.RequireAPIKey(os.Getenv("API_KEY"), mux))
}
