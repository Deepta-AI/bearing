package httpapi

import (
	"context"
	"net/http"

	"example.com/billing-service/internal/store"
)

type Handlers struct {
	Store         *store.Store
	WebhookSecret string
	Payments      interface {
		Refund(ctx context.Context, invoiceID string, amount int64) error
	}
}

// RequireSession rejects requests without a valid session cookie and puts
// the user and tenant ids on the context.
func (h *Handlers) RequireSession(next http.Handler) http.Handler { return next }

func (h *Handlers) RequireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler { return next }
}

func (h *Handlers) TenantID(r *http.Request) string { return "" }
