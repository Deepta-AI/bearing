package main

import (
	"log"
	"net/http"

	"example.com/orders/internal/api"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", api.Routes(api.SampleStore())))
}
