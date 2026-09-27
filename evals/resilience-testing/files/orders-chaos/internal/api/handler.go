package api

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"time"

	"example.com/orders/internal/cache"
	"example.com/orders/internal/payments"
	"example.com/orders/internal/store"
)

type Store interface {
	GetProduct(ctx context.Context, id string) (store.Product, error)
	CreateOrder(ctx context.Context, o store.Order) (string, error)
	Ping(ctx context.Context) error
}

type Cache interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Set(ctx context.Context, key string, val []byte, ttl time.Duration) error
	Ping(ctx context.Context) error
}

type Payments interface {
	Authorize(ctx context.Context, amountCents int64, cardToken string) (string, error)
}

type Handler struct {
	store Store
	cache Cache
	psp   Payments
}

func New(s Store, c Cache, p Payments) *Handler { return &Handler{store: s, cache: c, psp: p} }

func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /products/{id}", h.getProduct)
	mux.HandleFunc("POST /orders", h.createOrder)
	mux.HandleFunc("GET /healthz", h.healthz)
	return mux
}

func (h *Handler) getProduct(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	key := "product:" + id
	b, err := h.cache.Get(r.Context(), key)
	if err != nil && !errors.Is(err, cache.ErrMiss) {
		log.Printf("cache get %s: %v", key, err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if err == nil {
		w.Header().Set("Content-Type", "application/json")
		w.Write(b)
		return
	}
	p, err := h.store.GetProduct(r.Context(), id)
	if errors.Is(err, store.ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("get product %s: %v", id, err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	b, _ = json.Marshal(p)
	_ = h.cache.Set(r.Context(), key, b, 10*time.Minute)
	w.Header().Set("Content-Type", "application/json")
	w.Write(b)
}

type orderRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
	CardToken string `json:"card_token"`
}

func (h *Handler) createOrder(w http.ResponseWriter, r *http.Request) {
	var req orderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Quantity < 1 {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	p, err := h.store.GetProduct(r.Context(), req.ProductID)
	if err != nil {
		log.Printf("create order, product %s: %v", req.ProductID, err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	amount := p.PriceCents * int64(req.Quantity)
	authID, err := h.psp.Authorize(r.Context(), amount, req.CardToken)
	if err != nil {
		log.Printf("authorize: %v", err)
		http.Error(w, "payment failed", http.StatusBadGateway)
		return
	}
	id, err := h.store.CreateOrder(r.Context(), store.Order{
		ProductID: req.ProductID, Quantity: req.Quantity, AmountCents: amount, AuthID: authID,
	})
	if err != nil {
		log.Printf("create order: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"id": id})
}

// healthz is the liveness and readiness endpoint: the pod is healthy when it
// can reach both of its stores.
func (h *Handler) healthz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := h.store.Ping(ctx); err != nil {
		http.Error(w, "db: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	if err := h.cache.Ping(ctx); err != nil {
		http.Error(w, "cache: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	w.Write([]byte("ok"))
}

var _ Payments = (*payments.Client)(nil)
