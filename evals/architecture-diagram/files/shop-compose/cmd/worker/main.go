package main

import (
	"context"
	"database/sql"
	"log"
	"os"
	"time"

	"example.com/shop/internal/mail"
	"example.com/shop/internal/outbox"
)

func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	box := outbox.New(db)
	mailer := mail.New(os.Getenv("SMTP_HOST"))
	for {
		msgs, err := box.Claim(context.Background(), "order.created", 20)
		if err != nil {
			log.Printf("claim: %v", err)
		}
		for _, m := range msgs {
			if err := mailer.OrderConfirmation(m.Payload); err != nil {
				log.Printf("mail %d: %v", m.ID, err)
				_ = box.Release(context.Background(), m.ID)
				continue
			}
			_ = box.Done(context.Background(), m.ID)
		}
		time.Sleep(5 * time.Second)
	}
}
