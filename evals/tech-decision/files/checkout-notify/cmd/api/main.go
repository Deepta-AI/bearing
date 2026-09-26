package main

import (
	"log"
	"net/http"
	"os"

	"example.com/checkout/internal/checkout"
	"example.com/checkout/internal/notify"
	"example.com/checkout/internal/store"
)

func main() {
	db, err := store.Open(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	h := &checkout.Handler{
		Store: db,
		SMS:   notify.NewSMS(os.Getenv("MSG91_AUTH_KEY")),
		Email: notify.NewEmail(os.Getenv("POSTMARK_TOKEN")),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /checkout", h.Checkout)
	log.Fatal(http.ListenAndServe(":"+os.Getenv("PORT"), mux))
}
