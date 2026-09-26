package main

import (
	"context"
	"database/sql"
	"log"
	"os"
	"time"

	"example.com/shop/internal/outbox"
	"example.com/shop/internal/search"
)

// The indexer claims product.updated rows from the outbox and pushes the
// product document to Meilisearch.
func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	box := outbox.New(db)
	idx := search.NewClient(os.Getenv("SEARCH_URL"))
	for {
		msgs, err := box.Claim(context.Background(), "product.updated", 100)
		if err != nil {
			log.Printf("claim: %v", err)
		}
		for _, m := range msgs {
			if err := idx.Upsert(context.Background(), m.Payload); err != nil {
				log.Printf("index %d: %v", m.ID, err)
				_ = box.Release(context.Background(), m.ID)
				continue
			}
			_ = box.Done(context.Background(), m.ID)
		}
		time.Sleep(2 * time.Second)
	}
}
