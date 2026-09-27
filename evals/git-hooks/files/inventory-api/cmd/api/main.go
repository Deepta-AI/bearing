package main

import (
	"encoding/json"
	"log"
	"net/http"

	"example.com/inventory-api/internal/stock"
)

func main() {
	store := stock.NewStore()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /stock/{sku}", func(w http.ResponseWriter, r *http.Request) {
		level, ok := store.Level(r.PathValue("sku"))
		if !ok {
			http.NotFound(w, r)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]int{"level": level})
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
