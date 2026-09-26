package orders

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"

	"example.com/shop/internal/outbox"
	"example.com/shop/internal/payments"
)

var (
	ErrPaymentFailed = errors.New("payment failed")
	ErrNotRefundable = errors.New("order not refundable")
)

type Order struct {
	ID     string `json:"id"`
	Total  int64  `json:"total_paise"`
	Status string `json:"status"`
}

type Service struct {
	DB       *sql.DB
	Payments *payments.Client
	Outbox   *outbox.Outbox
}

// Place captures the payment, then writes the order and an order.created
// outbox row in one transaction. The worker picks the row up.
func (s *Service) Place(ctx context.Context, cartID, paymentID string) (Order, error) {
	var o Order
	if err := s.DB.QueryRowContext(ctx,
		`SELECT total_paise FROM carts WHERE id = $1`, cartID).Scan(&o.Total); err != nil {
		return o, err
	}
	if err := s.Payments.Capture(ctx, paymentID, o.Total); err != nil {
		return o, errors.Join(ErrPaymentFailed, err)
	}
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return o, err
	}
	defer tx.Rollback()
	if err := tx.QueryRowContext(ctx,
		`INSERT INTO orders (cart_id, payment_id, total_paise, status) VALUES ($1, $2, $3, 'paid') RETURNING id, status`,
		cartID, paymentID, o.Total).Scan(&o.ID, &o.Status); err != nil {
		return o, err
	}
	payload, _ := json.Marshal(o)
	if err := s.Outbox.Insert(ctx, tx, "order.created", payload); err != nil {
		return o, err
	}
	return o, tx.Commit()
}

// Refund returns the captured payment to the customer, marks the order
// refunded and queues order.refunded in the same transaction.
func (s *Service) Refund(ctx context.Context, id string) (Order, error) {
	var o Order
	var paymentID string
	err := s.DB.QueryRowContext(ctx,
		`SELECT id, payment_id, total_paise FROM orders WHERE id = $1 AND status = 'paid'`, id).
		Scan(&o.ID, &paymentID, &o.Total)
	if errors.Is(err, sql.ErrNoRows) {
		return o, ErrNotRefundable
	}
	if err != nil {
		return o, err
	}
	if err := s.Payments.Refund(ctx, paymentID, o.Total); err != nil {
		return o, errors.Join(ErrPaymentFailed, err)
	}
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return o, err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `UPDATE orders SET status = 'refunded' WHERE id = $1`, o.ID); err != nil {
		return o, err
	}
	o.Status = "refunded"
	payload, _ := json.Marshal(o)
	if err := s.Outbox.Insert(ctx, tx, "order.refunded", payload); err != nil {
		return o, err
	}
	return o, tx.Commit()
}

func (s *Service) Get(ctx context.Context, id string) (Order, error) {
	var o Order
	err := s.DB.QueryRowContext(ctx,
		`SELECT id, total_paise, status FROM orders WHERE id = $1`, id).Scan(&o.ID, &o.Total, &o.Status)
	return o, err
}

func (s *Service) List(ctx context.Context) ([]Order, error) {
	rows, err := s.DB.QueryContext(ctx, `SELECT id, total_paise, status FROM orders ORDER BY id DESC LIMIT 100`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Order
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.Total, &o.Status); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}
