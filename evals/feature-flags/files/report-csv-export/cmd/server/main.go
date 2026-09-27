package main

import (
	"log/slog"
	"net/http"
	"os"

	"example.com/reportsvc/internal/flags"
	"example.com/reportsvc/internal/reports"
)

func main() {
	fl := flags.FromEnv()
	store := reports.NewStore(
		reports.Report{ID: "demo", AccountID: "a1", Title: "Demo", Columns: []string{"k", "v"}, Rows: [][]string{{"a", "1"}}},
	)
	h := &reports.Handler{Store: store, Flags: fl, Audit: func(id string) { slog.Info("audit v2", "report", id) }}
	mux := http.NewServeMux()
	h.Routes(mux)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	slog.Info("listening", "port", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("server", "err", err)
		os.Exit(1)
	}
}
