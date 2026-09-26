package shipments

import (
	"context"
	"errors"
	"sync"
	"time"
)

var ErrNotFound = errors.New("shipment not found")

// Notifier sends customer emails. The SMTP implementation takes seconds.
type Notifier interface {
	SendDelivered(ctx context.Context, email, shipmentID string) error
}

type Shipment struct {
	ID          string
	Email       string
	Status      string
	DeliveredAt time.Time
}

type Service struct {
	mu       sync.Mutex
	byID     map[string]*Shipment
	Notifier Notifier
}

func NewService(n Notifier, seed ...Shipment) *Service {
	s := &Service{byID: map[string]*Shipment{}, Notifier: n}
	for i := range seed {
		sh := seed[i]
		s.byID[sh.ID] = &sh
	}
	return s
}

// MarkDelivered records the delivery and emails the customer.
func (s *Service) MarkDelivered(ctx context.Context, id string, at time.Time) error {
	s.mu.Lock()
	sh, ok := s.byID[id]
	if !ok {
		s.mu.Unlock()
		return ErrNotFound
	}
	sh.Status = "delivered"
	sh.DeliveredAt = at
	email := sh.Email
	s.mu.Unlock()
	return s.Notifier.SendDelivered(ctx, email, id)
}

// MarkInTransit records a movement.
func (s *Service) MarkInTransit(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	sh, ok := s.byID[id]
	if !ok {
		return ErrNotFound
	}
	sh.Status = "in_transit"
	return nil
}
