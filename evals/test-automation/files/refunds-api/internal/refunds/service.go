package refunds

import (
	"errors"
	"time"
)

// RefundWindow is how long after capture an order can be refunded.
const RefundWindow = 30 * 24 * time.Hour

var (
	ErrNotFound          = errors.New("not found")
	ErrNotCaptured       = errors.New("order not captured")
	ErrInvalidAmount     = errors.New("invalid amount")
	ErrExceedsRefundable = errors.New("exceeds refundable")
	ErrWindowClosed      = errors.New("refund window closed")
)

// Publisher sends domain events to the ledger topic.
type Publisher interface {
	Publish(topic string, payload any) error
}

// RefundCreated is the payload of the refund.created event.
type RefundCreated struct {
	OrderID     string `json:"order_id"`
	RefundID    string `json:"refund_id"`
	AmountPaise int64  `json:"amount_paise"`
}

type Service struct {
	store *Store
	pub   Publisher
	now   func() time.Time
}

func NewService(store *Store, pub Publisher, now func() time.Time) *Service {
	if now == nil {
		now = time.Now
	}
	return &Service{store: store, pub: pub, now: now}
}

// Create issues a refund of amount paise against a captured order.
func (s *Service) Create(orderID string, amount int64) (Refund, error) {
	o, ok := s.store.Order(orderID)
	if !ok {
		return Refund{}, ErrNotFound
	}
	if o.Status != "captured" {
		return Refund{}, ErrNotCaptured
	}
	if amount <= 0 {
		return Refund{}, ErrInvalidAmount
	}
	now := s.now()
	if now.Sub(o.CapturedAt) > RefundWindow {
		return Refund{}, ErrWindowClosed
	}
	if amount > o.TotalPaise {
		return Refund{}, ErrExceedsRefundable
	}
	r := s.store.AddRefund(orderID, amount, now)
	if err := s.pub.Publish("refund.created", RefundCreated{OrderID: orderID, RefundID: r.ID, AmountPaise: amount}); err != nil {
		return r, err
	}
	return r, nil
}

// Summary returns an order's refunds, the total refunded and what is left.
func (s *Service) Summary(orderID string) ([]Refund, int64, int64, error) {
	o, ok := s.store.Order(orderID)
	if !ok {
		return nil, 0, 0, ErrNotFound
	}
	rs := s.store.RefundsFor(orderID)
	var refunded int64
	for _, r := range rs {
		refunded += r.AmountPaise
	}
	return rs, refunded, o.TotalPaise - refunded, nil
}

func (s *Service) Get(id string) (Refund, error) {
	r, ok := s.store.Refund(id)
	if !ok {
		return Refund{}, ErrNotFound
	}
	return r, nil
}
