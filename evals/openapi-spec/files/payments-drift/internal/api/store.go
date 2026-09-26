package api

import (
	"fmt"
	"sync"
	"time"
)

type Payment struct {
	ID            string    `json:"id"`
	AmountMinor   int64     `json:"amount_minor"`
	Currency      string    `json:"currency"`
	CustomerID    string    `json:"customer_id"`
	Description   string    `json:"description,omitempty"`
	Status        string    `json:"status"` // authorized, captured, partially_refunded, refunded, failed
	RefundedMinor int64     `json:"refunded_minor"`
	CreatedAt     time.Time `json:"created_at"`
}

type Refund struct {
	ID          string    `json:"id"`
	PaymentID   string    `json:"payment_id"`
	AmountMinor int64     `json:"amount_minor"`
	Currency    string    `json:"currency"`
	Reason      string    `json:"reason,omitempty"`
	Status      string    `json:"status"` // pending, succeeded, failed
	CreatedAt   time.Time `json:"created_at"`
}

type Store struct {
	mu       sync.Mutex
	seq      int
	payments map[string]*Payment
	refunds  map[string]refundRecord // by Idempotency-Key
}

type refundRecord struct {
	bodyHash string
	refund   Refund
}

func NewMemoryStore() *Store {
	return &Store{payments: map[string]*Payment{}, refunds: map[string]refundRecord{}}
}

func (s *Store) nextID(prefix string) string {
	s.seq++
	return fmt.Sprintf("%s_%06d", prefix, s.seq)
}
