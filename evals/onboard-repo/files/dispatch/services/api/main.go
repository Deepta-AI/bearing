package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"

	"example.com/dispatch/api/internal/route"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/eta", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			DistanceM int `json:"distance_m"`
			Stops     int `json:"stops"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		mins, err := route.ETAMinutes(req.DistanceM, req.Stops)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnprocessableEntity)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]int{"eta_minutes": mins})
	})
	addr := ":" + envOr("PORT", "8081")
	slog.Info("api listening", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
