package main

import (
	"context"
	"log"
	"os"
	"os/signal"

	"example.com/clinic-desk/internal/db"
	"example.com/clinic-desk/internal/jobs"
)

func main() {
	conn, err := db.Open(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	w := &jobs.Worker{DB: conn, Handlers: map[string]jobs.Handler{
		"invoice.email": func(ctx context.Context, payload []byte) error { return nil },
	}}
	w.Run(ctx)
}
