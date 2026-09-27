// Package checkout serves carts, checkout and order history. Every route
// needs a customer bearer token (middleware in cmd/checkout-api).
package checkout

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
)

// Payments charges a card. PAYMENTS_MODE=sandbox (qa) never moves money;
// live (prod) does.
type Payments interface {
	Charge(ctx context.Context, cartID string, amountCents int64, method string) (chargeID string, err error)
}

func Routes(mux *http.ServeMux, db *sql.DB, pay Payments) {
	mux.HandleFunc("POST /checkout/carts", func(w http.ResponseWriter, r *http.Request) {
		var id string
		if err := db.QueryRowContext(r.Context(), `INSERT INTO carts DEFAULT VALUES RETURNING id`).Scan(&id); err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]string{"id": id})
	})
	mux.HandleFunc("POST /checkout/carts/{id}/items", func(w http.ResponseWriter, r *http.Request) {
		var it struct {
			SKU string `json:"sku"`
			Qty int    `json:"qty"`
		}
		if json.NewDecoder(r.Body).Decode(&it) != nil || it.Qty < 1 {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if _, err := db.ExecContext(r.Context(), `INSERT INTO cart_items (cart_id, sku, qty) VALUES ($1, $2, $3)`, r.PathValue("id"), it.SKU, it.Qty); err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("POST /checkout/carts/{id}/checkout", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			PaymentMethod string `json:"payment_method"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		var total int64
		if err := db.QueryRowContext(r.Context(), `SELECT coalesce(sum(i.qty * p.price_cents), 0) FROM cart_items i JOIN products p USING (sku) WHERE i.cart_id = $1`, r.PathValue("id")).Scan(&total); err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		charge, err := pay.Charge(r.Context(), r.PathValue("id"), total, req.PaymentMethod)
		if err != nil {
			http.Error(w, "payment failed", http.StatusPaymentRequired)
			return
		}
		var orderID string
		if err := db.QueryRowContext(r.Context(), `INSERT INTO orders (cart_id, charge_id, total_cents) VALUES ($1, $2, $3) RETURNING id`, r.PathValue("id"), charge, total).Scan(&orderID); err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]string{"order_id": orderID, "charge_id": charge})
	})
	mux.HandleFunc("GET /checkout/orders", func(w http.ResponseWriter, r *http.Request) {
		rows, err := db.QueryContext(r.Context(), `SELECT id, total_cents FROM orders ORDER BY created_at DESC LIMIT 20`)
		if err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		defer rows.Close()
		type o struct {
			ID    string `json:"id"`
			Total int64  `json:"total_cents"`
		}
		var out []o
		for rows.Next() {
			var x o
			if rows.Scan(&x.ID, &x.Total) == nil {
				out = append(out, x)
			}
		}
		_ = json.NewEncoder(w).Encode(out)
	})
}
