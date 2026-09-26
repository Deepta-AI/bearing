package httpapi

import "github.com/go-chi/chi/v5"

func Routes(h *Handlers) *chi.Mux {
	r := chi.NewRouter()
	r.Group(func(r chi.Router) {
		r.Use(h.RequireSession)
		r.Get("/invoices/{id}/pdf", h.InvoicePDF)
		r.With(h.RequireRole("admin")).Post("/imports/customers", h.ImportCustomersCSV)
		r.Post("/invoices/{id}/refunds", h.RefundInvoice)
	})
	// Razorpay calls this; no session.
	r.Post("/webhooks/razorpay", h.RazorpayWebhook)
	return r
}
