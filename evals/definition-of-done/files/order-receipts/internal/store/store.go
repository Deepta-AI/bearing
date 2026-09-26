// Package store holds orders. The demo store is in memory.
package store

import (
	"context"
	"errors"
	"sort"
	"sync"
)

// ErrNotFound is returned when no order has the id.
var ErrNotFound = errors.New("store: order not found")

// Line is one item on an order.
type Line struct {
	SKU        string `json:"sku"`
	Name       string `json:"name"`
	Qty        int    `json:"qty"`
	PricePaise int64  `json:"price_paise"`
}

// Order is a placed order.
type Order struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	Status     string `json:"status"`
	TotalPaise int64  `json:"total_paise"`
	Lines      []Line `json:"lines"`
}

// Memory is an in-memory order store, safe for concurrent use.
type Memory struct {
	mu     sync.RWMutex
	orders map[string]Order
}

// NewMemory returns a store holding the given orders.
func NewMemory(orders ...Order) *Memory {
	m := &Memory{orders: map[string]Order{}}
	for _, o := range orders {
		m.orders[o.ID] = o
	}
	return m
}

// Get returns the order with the id, or ErrNotFound.
func (m *Memory) Get(_ context.Context, id string) (Order, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	o, ok := m.orders[id]
	if !ok {
		return Order{}, ErrNotFound
	}
	return o, nil
}

// List returns every order, in id order.
func (m *Memory) List(_ context.Context) ([]Order, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]Order, 0, len(m.orders))
	for _, o := range m.orders {
		out = append(out, o)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// Demo is the store `make dev` starts with.
func Demo() *Memory {
	return NewMemory(
		Order{ID: "ord_1001", CustomerID: "cus_7", Status: "paid", TotalPaise: 149900,
			Lines: []Line{{SKU: "MUG-01", Name: "Stoneware mug", Qty: 2, PricePaise: 49950}, {SKU: "TEA-12", Name: "Assam tea 250 g", Qty: 1, PricePaise: 50000}}},
		Order{ID: "ord_1002", CustomerID: "cus_9", Status: "shipped", TotalPaise: 89900,
			Lines: []Line{{SKU: "PAN-03", Name: "Cast iron pan", Qty: 1, PricePaise: 89900}}},
	)
}
