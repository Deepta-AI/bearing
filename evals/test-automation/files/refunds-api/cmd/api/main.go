package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"

	"example.com/refunds/internal/refunds"
)

// logPublisher stands in for the ledger topic until PAY-231.
type logPublisher struct{ log *slog.Logger }

func (p logPublisher) Publish(topic string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	p.log.Info("event", "topic", topic, "payload", string(b))
	return nil
}

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	store := refunds.NewStore()
	mux := http.NewServeMux()
	refunds.Routes(mux, refunds.NewService(store, logPublisher{log: log}, nil))
	addr := ":8080"
	log.Info("listening", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
