package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"example.com/webhook-receiver/internal/webhook"
)

func main() {
	secret := os.Getenv("WEBHOOK_SIGNING_SECRET")
	if secret == "" {
		log.Fatal("WEBHOOK_SIGNING_SECRET is not set")
	}
	h := &webhook.Handler{
		Secret:    []byte(secret),
		Store:     webhook.NewMemoryStore(),
		Now:       time.Now,
		Tolerance: 5 * time.Minute,
	}
	mux := http.NewServeMux()
	mux.Handle("POST /webhooks/payments", h)
	log.Fatal(http.ListenAndServe(":8080", mux))
}
