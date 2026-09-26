// Command billingd serves the billing API.
package main

import (
	"flag"
	"log/slog"
	"net/http"
	"os"

	"example.com/billingsvc/api"
	"example.com/billingsvc/billing"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	data := flag.String("data", "data/clients.json", "clients file")
	flag.Parse()

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	store, err := billing.LoadFile(*data)
	if err != nil {
		log.Error("load clients", "err", err)
		os.Exit(1)
	}
	api.RefreshMetrics(store)
	h := &api.Handler{Store: store, Log: log}
	log.Info("listening", "addr", *addr, "clients", len(store.ActiveClients()))
	if err := http.ListenAndServe(*addr, h.Routes()); err != nil {
		log.Error("serve", "err", err)
		os.Exit(1)
	}
}
