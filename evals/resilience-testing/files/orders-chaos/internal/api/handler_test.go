package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"example.com/orders/internal/cache"
	"example.com/orders/internal/store"
)

type fakeStore struct {
	products map[string]store.Product
	pingErr  error
}

func (f *fakeStore) GetProduct(_ context.Context, id string) (store.Product, error) {
	p, ok := f.products[id]
	if !ok {
		return store.Product{}, store.ErrNotFound
	}
	return p, nil
}
func (f *fakeStore) CreateOrder(context.Context, store.Order) (string, error) { return "ord_1", nil }
func (f *fakeStore) Ping(context.Context) error                               { return f.pingErr }

type fakeCache struct{ m map[string][]byte }

func (f *fakeCache) Get(_ context.Context, k string) ([]byte, error) {
	b, ok := f.m[k]
	if !ok {
		return nil, cache.ErrMiss
	}
	return b, nil
}
func (f *fakeCache) Set(_ context.Context, k string, v []byte, _ time.Duration) error {
	f.m[k] = v
	return nil
}
func (f *fakeCache) Ping(context.Context) error { return nil }

type fakePSP struct{}

func (fakePSP) Authorize(context.Context, int64, string) (string, error) { return "auth_1", nil }

func newTestHandler() (*Handler, *fakeStore, *fakeCache) {
	s := &fakeStore{products: map[string]store.Product{"p1": {ID: "p1", Name: "Mug", PriceCents: 1200}}}
	c := &fakeCache{m: map[string][]byte{}}
	return New(s, c, fakePSP{}), s, c
}

func TestGetProductMissThenHit(t *testing.T) {
	h, _, c := newTestHandler()
	srv := h.Routes()
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest("GET", "/products/p1", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	if _, ok := c.m["product:p1"]; !ok {
		t.Fatal("product was not cached")
	}
}

func TestCreateOrder(t *testing.T) {
	h, _, _ := newTestHandler()
	rec := httptest.NewRecorder()
	body := strings.NewReader(`{"product_id":"p1","quantity":2,"card_token":"tok"}`)
	h.Routes().ServeHTTP(rec, httptest.NewRequest("POST", "/orders", body))
	if rec.Code != http.StatusCreated {
		t.Fatalf("status %d", rec.Code)
	}
}

func TestHealthzOK(t *testing.T) {
	h, _, _ := newTestHandler()
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest("GET", "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
}
