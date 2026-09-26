package main

import (
	"log"
	"net/http"

	"example.com/customers/internal/api"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", api.Routes()))
}
