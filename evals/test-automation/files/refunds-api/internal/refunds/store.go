package refunds

import (
	"fmt"
	"sync"
	"time"
)

// Order is a captured (or only authorized) order copied from payments.
type Order struct {
	ID         string
	TotalPaise int64
	Status     string // "authorized" or "captured"
	CapturedAt time.Time
}

// Refund is one refund against an order.
type Refund struct {
	ID          string    `json:"id"`
	OrderID     string    `json:"order_id"`
	AmountPaise int64     `json:"amount_paise"`
	CreatedAt   time.Time `json:"created_at"`
}

// Store keeps orders and refunds in memory.
type Store struct {
	mu      sync.Mutex
	orders  map[string]Order
	refunds []Refund
	seq     int
}

func NewStore() *Store {
	return &Store{orders: map[string]Order{}}
}

func (s *Store) PutOrder(o Order) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.orders[o.ID] = o
}

func (s *Store) Order(id string) (Order, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	o, ok := s.orders[id]
	return o, ok
}

func (s *Store) AddRefund(orderID string, amount int64, at time.Time) Refund {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seq++
	r := Refund{ID: fmt.Sprintf("ref_%d", s.seq), OrderID: orderID, AmountPaise: amount, CreatedAt: at}
	s.refunds = append(s.refunds, r)
	return r
}

func (s *Store) Refund(id string) (Refund, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, r := range s.refunds {
		if r.ID == id {
			return r, true
		}
	}
	return Refund{}, false
}

func (s *Store) RefundsFor(orderID string) []Refund {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []Refund{}
	for _, r := range s.refunds {
		if r.OrderID == orderID {
			out = append(out, r)
		}
	}
	return out
}
