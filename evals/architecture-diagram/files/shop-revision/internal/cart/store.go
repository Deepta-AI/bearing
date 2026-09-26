// Package cart keeps carts in Postgres. Until 1.9.0 they were cached in
// Redis (ADR 0002); the Redis client was removed in SHOP-72.
package cart

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
)

type Store struct{ db *sql.DB }

func NewStore(db *sql.DB) *Store { return &Store{db: db} }

func (s *Store) Load(ctx context.Context, sessionID string) ([]byte, error) {
	var items []byte
	err := s.db.QueryRowContext(ctx,
		`SELECT items FROM carts WHERE session_id = $1`, sessionID).Scan(&items)
	if err == sql.ErrNoRows {
		return []byte("[]"), nil
	}
	return items, err
}

func (s *Store) Save(ctx context.Context, sessionID string, items []byte) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO carts (session_id, items) VALUES ($1, $2)
		 ON CONFLICT (session_id) DO UPDATE SET items = EXCLUDED.items`, sessionID, items)
	return err
}

type Handler struct{ Store *Store }

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.Load(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, "could not load cart", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(items)
}

func (h *Handler) Put(w http.ResponseWriter, r *http.Request) {
	var items json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&items); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if err := h.Store.Save(r.Context(), r.Header.Get("Authorization"), items); err != nil {
		http.Error(w, "could not save cart", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
