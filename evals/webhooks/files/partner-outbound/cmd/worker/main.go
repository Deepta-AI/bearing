package main

import (
	"log"
	"time"

	"example.com/shopcore/internal/outbox"
)

// The worker drains the outbox. Today nothing consumes the events; they
// are only marked processed.
func main() {
	ob := outbox.NewMemory()
	for range time.Tick(2 * time.Second) {
		evs, err := ob.Pending(100)
		if err != nil {
			log.Printf("outbox: %v", err)
			continue
		}
		for _, ev := range evs {
			_ = ob.MarkProcessed(ev.ID)
		}
	}
}
