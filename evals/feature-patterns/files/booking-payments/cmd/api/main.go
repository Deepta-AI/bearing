package main

import (
	"log"
	"net/http"
	"os"

	"example.com/clinic-bookings/internal/bookings"
	"example.com/clinic-bookings/internal/payments"
)

func main() {
	mux := http.NewServeMux()
	b := &bookings.Handlers{}
	mux.HandleFunc("POST /bookings", b.Create)
	mux.HandleFunc("POST /bookings/{id}/confirm-payment", b.ConfirmPayment)
	mux.Handle("POST /webhooks/razorpay", &payments.Webhook{Secret: os.Getenv("RAZORPAY_WEBHOOK_SECRET")})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
