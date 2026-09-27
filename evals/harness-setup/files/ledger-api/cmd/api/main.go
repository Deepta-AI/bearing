package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"example.com/ledger-api/internal/ledger"
)

func main() {
	book := ledger.New()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /accounts/{id}/balance", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]int64{"balance_minor": book.Balance(r.PathValue("id"))})
	})
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	log.Fatal(http.ListenAndServe(addr, mux))
}
