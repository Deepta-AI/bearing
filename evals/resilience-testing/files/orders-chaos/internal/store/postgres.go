package store

import (
	"context"
	"database/sql"
	"errors"
)

var ErrNotFound = errors.New("not found")

type Product struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	PriceCents int64  `json:"price_cents"`
}

type Order struct {
	ProductID   string
	Quantity    int
	AmountCents int64
	AuthID      string
}

type Postgres struct{ db *sql.DB }

func NewPostgres(db *sql.DB) *Postgres { return &Postgres{db: db} }

func (p *Postgres) GetProduct(ctx context.Context, id string) (Product, error) {
	var pr Product
	err := p.db.QueryRowContext(ctx,
		`SELECT id, name, price_cents FROM products WHERE id = $1`, id).
		Scan(&pr.ID, &pr.Name, &pr.PriceCents)
	if errors.Is(err, sql.ErrNoRows) {
		return Product{}, ErrNotFound
	}
	return pr, err
}

func (p *Postgres) CreateOrder(ctx context.Context, o Order) (string, error) {
	var id string
	err := p.db.QueryRowContext(ctx,
		`INSERT INTO orders (product_id, quantity, amount_cents, psp_auth_id)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		o.ProductID, o.Quantity, o.AmountCents, o.AuthID).Scan(&id)
	return id, err
}

func (p *Postgres) Ping(ctx context.Context) error { return p.db.PingContext(ctx) }
