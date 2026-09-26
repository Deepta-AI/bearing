package main

import (
	"log"
	"net/http"

	"example.com/clinic-api/internal/httpapi"
	"example.com/clinic-api/internal/store"
)

func main() {
	s := store.Seeded()
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", httpapi.Routes(s)))
}
