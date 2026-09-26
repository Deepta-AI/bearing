package main

import (
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/notifier/internal/webhook"
)

func main() {
	secret := []byte(os.Getenv("WEBHOOK_SECRET"))
	http.HandleFunc("POST /webhooks/partner", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		if err != nil {
			http.Error(w, "read error", http.StatusBadRequest)
			return
		}
		if err := webhook.Verify(secret, r.Header.Get("X-Timestamp"), body, r.Header.Get("X-Signature"), time.Now()); err != nil {
			http.Error(w, "invalid signature", http.StatusUnauthorized)
			return
		}
		w.WriteHeader(http.StatusAccepted)
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
