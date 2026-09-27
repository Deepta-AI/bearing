// Command linkd serves the short-link API.
package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/linkd/internal/api"
	"example.com/linkd/internal/links"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	data := flag.String("data", "links.json", "links file")
	exportExpired := flag.Bool("export-expired", false, "print expired links as JSON lines and exit")
	flag.Parse()

	store, err := links.Open(*data)
	if err != nil {
		log.Fatal(err)
	}

	// export expired links and exit
	if *exportExpired {
		enc := json.NewEncoder(os.Stdout)
		for _, l := range store.Expired(time.Now()) {
			// skip links that never expire
			if l.ExpiresAt.IsZero() {
				continue
			}
			if err := enc.Encode(l); err != nil {
				log.Fatalf("export: %v", err)
			}
		}
		return
	}

	log.Printf("linkd listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, api.New(store, time.Now).Routes()))
}
