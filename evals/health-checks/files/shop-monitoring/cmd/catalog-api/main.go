package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"

	"example.com/shop/internal/catalog"
)

type index struct{ url string }

func (i index) Ping(ctx context.Context) error { return nil }
func (i index) Search(ctx context.Context, q string, limit int) ([]string, error) {
	return nil, nil
}

func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	mux := http.NewServeMux()
	catalog.Routes(mux, db, index{url: os.Getenv("SEARCH_URL")})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
