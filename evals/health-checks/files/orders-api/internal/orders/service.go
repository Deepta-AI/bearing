// Package orders takes and reads orders.
package orders

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"example.com/orders-api/internal/outbox"
	"example.com/orders-api/internal/pricing"
)

type Cache interface {
	Get(ctx context.Context, key string) (string, error)
	Set(ctx context.Context, key, value string, ttl time.Duration) error
}

type Pricer interface {
	Quote(ctx context.Context, sku string) (pricing.Quote, error)
}

type Line struct {
	SKU            string `json:"sku"`
	Qty            int    `json:"qty"`
	ListPriceCents int64  `json:"list_price_cents"`
	PriceCents     int64  `json:"price_cents"`
}

type Order struct {
	ID         int64  `json:"id"`
	CustomerID string `json:"customer_id"`
	Lines      []Line `json:"lines"`
	TotalCents int64  `json:"total_cents"`
}

type Service struct {
	db     *sql.DB
	cache  Cache
	prices Pricer
}

func NewService(db *sql.DB, c Cache, p Pricer) *Service {
	return &Service{db: db, cache: c, prices: p}
}

// Price fills PriceCents from pricing-api, falling back to the list price
// carried in the request when pricing-api fails.
func (s *Service) Price(ctx context.Context, lines []Line) []Line {
	out := make([]Line, len(lines))
	for i, l := range lines {
		l.PriceCents = l.ListPriceCents
		if q, err := s.prices.Quote(ctx, l.SKU); err == nil {
			l.PriceCents = q.PriceCents
		}
		out[i] = l
	}
	return out
}

func Total(lines []Line) int64 {
	var t int64
	for _, l := range lines {
		t += l.PriceCents * int64(l.Qty)
	}
	return t
}

func (s *Service) Create(ctx context.Context, customerID string, lines []Line) (Order, error) {
	if len(lines) == 0 {
		return Order{}, errors.New("orders: no lines")
	}
	o := Order{CustomerID: customerID, Lines: s.Price(ctx, lines)}
	o.TotalCents = Total(o.Lines)
	body, _ := json.Marshal(o.Lines)

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Order{}, err
	}
	defer tx.Rollback()
	if err := tx.QueryRowContext(ctx,
		`INSERT INTO orders (customer_id, lines, total_cents) VALUES ($1, $2, $3) RETURNING id`,
		customerID, body, o.TotalCents).Scan(&o.ID); err != nil {
		return Order{}, err
	}
	if err := outbox.Write(ctx, tx, "order.created", o); err != nil {
		return Order{}, err
	}
	return o, tx.Commit()
}

// Get reads through the cache; any cache error falls through to Postgres.
func (s *Service) Get(ctx context.Context, id int64) (Order, error) {
	key := "order:" + itoa(id)
	if v, err := s.cache.Get(ctx, key); err == nil {
		var o Order
		if json.Unmarshal([]byte(v), &o) == nil {
			return o, nil
		}
	}
	var o Order
	var lines []byte
	err := s.db.QueryRowContext(ctx,
		`SELECT id, customer_id, lines, total_cents FROM orders WHERE id = $1`, id).
		Scan(&o.ID, &o.CustomerID, &lines, &o.TotalCents)
	if err != nil {
		return Order{}, err
	}
	_ = json.Unmarshal(lines, &o.Lines)
	if b, err := json.Marshal(o); err == nil {
		_ = s.cache.Set(ctx, key, string(b), 10*time.Minute)
	}
	return o, nil
}

func itoa(n int64) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}
