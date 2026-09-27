// Command api runs the ledgerly HTTP server.
package main

import (
	"log"
	"net/http"
	"os"

	"example.com/ledgerly/internal/auth"
	"example.com/ledgerly/internal/invoices"
	"example.com/ledgerly/internal/webhooks"
)

type noUsers struct{}

func (noUsers) ByEmail(string) (auth.User, bool) { return auth.User{}, false }

func main() {
	keys := auth.Keys{} // loaded from the keys table in production
	store := invoices.NewStore()
	inv := invoices.Handler{Store: store}

	mux := http.NewServeMux()
	mux.Handle("POST /login", auth.Login(noUsers{}, func(http.ResponseWriter, auth.User) {}))
	mux.Handle("GET /api/v1/invoices", keys.RequireAuth(http.HandlerFunc(inv.List)))
	mux.Handle("GET /api/v1/invoices/{id}", keys.RequireAuth(http.HandlerFunc(inv.Get)))
	mux.HandleFunc("GET /api/v1/invoices/{id}/pdf", inv.PDF)
	mux.Handle("POST /api/v1/webhooks/payment", webhooks.Payment{
		Secret:   []byte(os.Getenv("PAYMENT_WEBHOOK_SECRET")),
		MarkPaid: store.MarkPaid,
	})

	log.Fatal(http.ListenAndServe(":8080", mux))
}
