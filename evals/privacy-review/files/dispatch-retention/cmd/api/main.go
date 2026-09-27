// Command api serves the HTTP API.
package main

import (
	"context"
	"log"
	"net/http"

	"example.com/dispatch/internal/api"
)

type noStore struct{}

func (noStore) DeliveriesForPhone(context.Context, string) ([]api.Delivery, error) { return nil, nil }

func main() {
	mux := http.NewServeMux()
	mux.Handle("GET /track", api.Track(noStore{}))
	log.Fatal(http.ListenAndServe(":8080", api.AccessLog(mux)))
}
