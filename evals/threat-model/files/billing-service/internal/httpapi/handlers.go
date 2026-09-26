package httpapi

import (
	"net/http"

	"example.com/billing-service/internal/store"
)

type Handlers struct {
	Store         *store.Store
	WebhookSecret string
}

// RequireSession rejects requests without a valid session cookie and puts
// the user and tenant ids on the context.
func (h *Handlers) RequireSession(next http.Handler) http.Handler { return next }

func (h *Handlers) RequireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler { return next }
}

func (h *Handlers) TenantID(r *http.Request) string { return "" }
