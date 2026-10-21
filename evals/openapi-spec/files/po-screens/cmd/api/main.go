package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	// Purchase order handlers come after the contract is agreed (PROC-17).
	log.Fatal(http.ListenAndServe(":8080", mux))
}
