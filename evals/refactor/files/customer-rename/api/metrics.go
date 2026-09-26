package api

import (
	"expvar"

	"example.com/billingsvc/billing"
)

var activeClients = expvar.NewInt("billing_clients_active")

// RefreshMetrics sets the active-client gauge from the store.
func RefreshMetrics(s *billing.Store) {
	activeClients.Set(int64(len(s.ActiveClients())))
}
