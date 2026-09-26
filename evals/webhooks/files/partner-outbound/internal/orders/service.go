package orders

import (
	"errors"
	"sync"
	"time"

	"example.com/shopcore/internal/outbox"
)

var ErrNotFound = errors.New("order not found")

type Order struct {
	ID         string
	PartnerID  string
	Status     string
	TotalMinor int64
	Currency   string
	UpdatedAt  time.Time
}

type Service struct {
	mu     sync.Mutex
	orders map[string]*Order
	Outbox outbox.Store
}

func NewService(ob outbox.Store, seed ...Order) *Service {
	s := &Service{orders: map[string]*Order{}, Outbox: ob}
	for i := range seed {
		o := seed[i]
		s.orders[o.ID] = &o
	}
	return s
}

type ShippedPayload struct {
	OrderID    string    `json:"order_id"`
	PartnerID  string    `json:"partner_id"`
	Carrier    string    `json:"carrier"`
	TrackingNo string    `json:"tracking_no"`
	ShippedAt  time.Time `json:"shipped_at"`
}

type CancelledPayload struct {
	OrderID     string    `json:"order_id"`
	PartnerID   string    `json:"partner_id"`
	Reason      string    `json:"reason"`
	CancelledAt time.Time `json:"cancelled_at"`
}

// Ship marks the order shipped and records order.shipped in the outbox
// (one transaction in the Postgres implementation).
func (s *Service) Ship(id, carrier, trackingNo string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	o, ok := s.orders[id]
	if !ok {
		return ErrNotFound
	}
	o.Status, o.UpdatedAt = "shipped", time.Now().UTC()
	_, err := s.Outbox.Add("order.shipped", ShippedPayload{o.ID, o.PartnerID, carrier, trackingNo, o.UpdatedAt})
	return err
}

// Cancel marks the order cancelled and records order.cancelled.
func (s *Service) Cancel(id, reason string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	o, ok := s.orders[id]
	if !ok {
		return ErrNotFound
	}
	o.Status, o.UpdatedAt = "cancelled", time.Now().UTC()
	_, err := s.Outbox.Add("order.cancelled", CancelledPayload{o.ID, o.PartnerID, reason, o.UpdatedAt})
	return err
}
