package store

import (
	"context"
	"database/sql"
	"fmt"
)

type Store struct{ db *sql.DB }

type Order struct {
	Number string
	Items  int
	Total  int64 // paise
}

func (o Order) Summary() string {
	return fmt.Sprintf("%d items, Rs %d.%02d", o.Items, o.Total/100, o.Total%100)
}

func Open(dsn string) (*Store, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}
	return &Store{db: db}, nil
}

// PlaceOrder turns a cart into an order in one transaction.
func (s *Store) PlaceOrder(ctx context.Context, cartID string) (Order, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Order{}, err
	}
	defer tx.Rollback()
	var o Order
	err = tx.QueryRowContext(ctx,
		`INSERT INTO orders (cart_id, number, items, total_paise)
		 SELECT id, 'ORD-' || nextval('order_numbers'), item_count, total_paise FROM carts WHERE id = $1
		 RETURNING number, items, total_paise`, cartID).Scan(&o.Number, &o.Items, &o.Total)
	if err != nil {
		return Order{}, err
	}
	return o, tx.Commit()
}
