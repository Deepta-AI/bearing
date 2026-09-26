package orders

import (
	"errors"
	"fmt"
	"log"
	"sort"
	"sync"
)

type Order struct {
	ID     string `json:"id"`
	Email  string `json:"-"`
	SKU    string `json:"sku"`
	Qty    int    `json:"qty"`
	Status string `json:"status"`
}

var (
	ErrBadQty  = errors.New("quantity must be between 1 and 50")
	ErrBlocked = errors.New("customer is blocked")
)

// blocked customers, from the fraud team's list.
var blocked = map[string]bool{"chargeback@example.com": true}

type MemStore struct {
	mu     sync.Mutex
	orders map[string]Order
	seq    int
}

func NewMemStore() *MemStore { return &MemStore{orders: map[string]Order{}} }

type Service struct{ store *MemStore }

func NewService(s *MemStore) *Service { return &Service{store: s} }

func (s *Service) Create(email, sku string, qty int) (Order, error) {
	if qty < 1 || qty > 50 {
		log.Printf("ERROR bad qty %d for %s", qty, email)
		return Order{}, ErrBadQty
	}
	if blocked[email] {
		return Order{}, fmt.Errorf("create order for %s: %w", email, ErrBlocked)
	}
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	s.store.seq++
	o := Order{ID: fmt.Sprintf("o-%d", s.store.seq), Email: email, SKU: sku, Qty: qty, Status: "pending"}
	s.store.orders[o.ID] = o
	return o, nil
}

func (s *Service) Get(id string) (Order, bool) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	o, ok := s.store.orders[id]
	return o, ok
}

// ListByEmail returns a customer's orders, oldest first.
func (s *Service) ListByEmail(email string) []Order {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	var out []Order
	for _, o := range s.store.orders {
		if o.Email == email {
			out = append(out, o)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// All returns every order, oldest first.
func (s *Service) All() []Order {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	out := make([]Order, 0, len(s.store.orders))
	for _, o := range s.store.orders {
		out = append(out, o)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// FulfilPending ships every pending order and tells the customer. A failed
// notification does not stop the run; the first one is returned.
func (s *Service) FulfilPending(n Notifier) (int, error) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	done := 0
	var first error
	for id, o := range s.store.orders {
		if o.Status != "pending" {
			continue
		}
		o.Status = "fulfilled"
		s.store.orders[id] = o
		done++
		if err := n.OrderShipped(o); err != nil && first == nil {
			first = fmt.Errorf("fulfil %s: %w", o.ID, err)
		}
	}
	return done, first
}
