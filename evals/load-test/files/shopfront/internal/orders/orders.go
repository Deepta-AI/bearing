// Package orders places and reads orders.
package orders

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

type Item struct {
	SKU        string `json:"sku"`
	Qty        int    `json:"qty"`
	PricePaise int64  `json:"price_paise"`
}

type Order struct {
	ID         string    `json:"id"`
	Email      string    `json:"email"`
	Items      []Item    `json:"items"`
	TotalPaise int64     `json:"total_paise"`
	CreatedAt  time.Time `json:"created_at"`
}

type Store interface {
	Put(Order) error
	Get(id string) (Order, bool)
}

// MemoryStore keeps every order for the life of the process.
type MemoryStore struct {
	mu     sync.RWMutex
	orders map[string]Order
}

func NewMemoryStore() *MemoryStore { return &MemoryStore{orders: map[string]Order{}} }

func (s *MemoryStore) Put(o Order) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.orders[o.ID] = o
	return nil
}

func (s *MemoryStore) Get(id string) (Order, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	o, ok := s.orders[id]
	return o, ok
}

type Handler struct {
	store Store
	seq   atomic.Int64
}

func NewHandler(s Store) *Handler { return &Handler{store: s} }

type createReq struct {
	Email string `json:"email"`
	Items []Item `json:"items"`
}

var errInvalid = errors.New("invalid order")

func validate(r createReq) error {
	if r.Email == "" || len(r.Items) == 0 {
		return errInvalid
	}
	for _, it := range r.Items {
		if it.SKU == "" || it.Qty <= 0 || it.PricePaise <= 0 {
			return errInvalid
		}
	}
	return nil
}

// Create handles POST /v1/orders.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var req createReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || validate(req) != nil {
		http.Error(w, "invalid order", http.StatusBadRequest)
		return
	}
	o := Order{ID: fmt.Sprintf("ord_%d", h.seq.Add(1)), Email: req.Email, Items: req.Items, CreatedAt: time.Now().UTC()}
	for _, it := range req.Items {
		o.TotalPaise += int64(it.Qty) * it.PricePaise
	}
	if err := h.store.Put(o); err != nil {
		http.Error(w, "order store unavailable", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(o)
}

// Get handles GET /v1/orders/{id}.
func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	o, ok := h.store.Get(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(o)
}
