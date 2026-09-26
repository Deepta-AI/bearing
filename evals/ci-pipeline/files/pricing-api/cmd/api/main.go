// Command api serves the pricing API on :8080.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/pricing-api/internal/httpapi"
)

func main() {
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           httpapi.NewMux(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
