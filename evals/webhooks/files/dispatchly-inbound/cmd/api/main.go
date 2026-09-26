package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"example.com/parcelpost/internal/jobs"
	"example.com/parcelpost/internal/shipments"
	"example.com/parcelpost/internal/webhooks"
)

type smtpNotifier struct{}

func (smtpNotifier) SendDelivered(ctx context.Context, email, id string) error {
	log.Printf("smtp: delivered email for %s", id)
	return nil
}

func main() {
	q := jobs.NewQueue(1024)
	go q.Run(context.Background())

	svc := shipments.NewService(smtpNotifier{})
	mux := http.NewServeMux()
	mux.Handle("POST /webhooks/dispatchly", &webhooks.Dispatchly{
		Secret:    []byte(os.Getenv("DISPATCHLY_WEBHOOK_SECRET")),
		Shipments: svc,
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
