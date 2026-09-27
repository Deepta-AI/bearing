// Package catalog serves products and search.
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
)

type SearchIndex interface {
	Ping(ctx context.Context) error
	Search(ctx context.Context, q string, limit int) ([]string, error)
}

type Product struct {
	SKU        string `json:"sku"`
	Name       string `json:"name"`
	PriceCents int64  `json:"price_cents"`
}

func Routes(mux *http.ServeMux, db *sql.DB, idx SearchIndex) {
	mux.HandleFunc("GET /healthz", Healthz)
	mux.HandleFunc("GET /readyz", Readyz(db, idx))
	mux.HandleFunc("GET /catalog/products", func(w http.ResponseWriter, r *http.Request) {
		rows, err := db.QueryContext(r.Context(), `SELECT sku, name, price_cents FROM products ORDER BY sku LIMIT 50`)
		if err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		defer rows.Close()
		var out []Product
		for rows.Next() {
			var p Product
			if rows.Scan(&p.SKU, &p.Name, &p.PriceCents) == nil {
				out = append(out, p)
			}
		}
		_ = json.NewEncoder(w).Encode(out)
	})
	mux.HandleFunc("GET /catalog/search", func(w http.ResponseWriter, r *http.Request) {
		skus, err := idx.Search(r.Context(), r.URL.Query().Get("q"), 20)
		if err != nil {
			http.Error(w, "unavailable", http.StatusServiceUnavailable)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"skus": skus})
	})
}
