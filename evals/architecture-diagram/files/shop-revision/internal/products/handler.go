package products

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"

	"example.com/shop/internal/outbox"
	"example.com/shop/internal/search"
)

type Handler struct {
	DB     *sql.DB
	Outbox *outbox.Outbox
	Index  *search.Client
}

// Search answers the storefront search box straight from Meilisearch.
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	body, err := h.Index.Query(r.Context(), r.URL.Query().Get("q"))
	if err != nil {
		http.Error(w, "search unavailable", http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(body)
}

// Update saves a product and queues product.updated for the indexer in the
// same transaction.
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(r.Body)
	if err != nil || !json.Valid(raw) {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	tx, err := h.DB.BeginTx(r.Context(), nil)
	if err != nil {
		http.Error(w, "could not save", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(r.Context(),
		`UPDATE products SET doc = $2 WHERE id = $1`, r.PathValue("id"), raw); err != nil {
		http.Error(w, "could not save", http.StatusInternalServerError)
		return
	}
	if err := h.Outbox.Insert(r.Context(), tx, "product.updated", raw); err != nil {
		http.Error(w, "could not save", http.StatusInternalServerError)
		return
	}
	if err := tx.Commit(); err != nil {
		http.Error(w, "could not save", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
