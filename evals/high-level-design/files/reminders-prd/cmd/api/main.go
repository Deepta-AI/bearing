package main

import (
	"log"
	"net/http"
	"os"

	"example.com/clinic-desk/internal/appointments"
	"example.com/clinic-desk/internal/db"
)

func main() {
	conn, err := db.Open(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	mux := http.NewServeMux()
	(&appointments.Handler{Store: &appointments.Store{DB: conn}}).Routes(mux)
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	log.Fatal(http.ListenAndServe(addr, mux))
}
