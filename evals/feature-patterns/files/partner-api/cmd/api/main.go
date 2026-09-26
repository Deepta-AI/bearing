package main

import (
	"log"
	"net/http"

	"example.com/partner-api/internal/httpapi"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", httpapi.Routes()))
}
