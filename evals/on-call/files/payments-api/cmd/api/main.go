package main

import (
	"log"
	"net/http"
	"os"

	"example.com/payments-api/internal/httpapi"
)

func main() {
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	srv := httpapi.New()
	log.Printf("payments-api listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, srv))
}
