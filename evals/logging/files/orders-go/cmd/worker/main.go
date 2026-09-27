package main

import (
	"context"
	"log"
	"time"

	"example.com/orders/internal/orders"
)

func main() {
	svc := orders.NewService(orders.NewMemStore())
	n := orders.Notifier{}
	for {
		done, err := svc.FulfilPending(context.Background(), n)
		if err != nil {
			log.Printf("fulfil failed: %v", err)
		}
		log.Printf("fulfilled %d orders", done)
		time.Sleep(5 * time.Second)
	}
}
