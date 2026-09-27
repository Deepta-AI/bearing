package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/orders/internal/api"
	"example.com/orders/internal/cache"
	"example.com/orders/internal/payments"
	"example.com/orders/internal/store"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	db.SetMaxOpenConns(20)
	db.SetConnMaxLifetime(5 * time.Minute)

	h := api.New(
		store.NewPostgres(db),
		cache.NewRedis(os.Getenv("REDIS_ADDR")),
		payments.NewClient(os.Getenv("PSP_URL")),
	)

	srv := &http.Server{
		Addr:         ":8080",
		Handler:      h.Routes(),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	log.Printf("orders-api listening on %s", srv.Addr)
	log.Fatal(srv.ListenAndServe())
}
