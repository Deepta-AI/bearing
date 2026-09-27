// Command linkd serves the short-link API.
package main

import (
	"flag"
	"log"
	"net/http"
	"time"

	"example.com/linkd/internal/api"
	"example.com/linkd/internal/links"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	data := flag.String("data", "links.json", "links file")
	flag.Parse()

	store, err := links.Open(*data)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("linkd listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, api.New(store, time.Now).Routes()))
}
