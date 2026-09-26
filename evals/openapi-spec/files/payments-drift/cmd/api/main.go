package main

import (
	"log"
	"net/http"

	"example.com/payments/internal/api"
)

func main() {
	s := api.NewServer(api.NewMemoryStore())
	log.Fatal(http.ListenAndServe(":8080", s.Routes()))
}
