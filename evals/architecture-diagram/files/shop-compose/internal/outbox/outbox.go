// Package outbox is a Postgres table used as the queue between the api
// and the worker: the api inserts rows in the order transaction, the
// worker claims them with SKIP LOCKED.
package outbox

import (
	"context"
	"database/sql"
)

type Outbox struct{ db *sql.DB }

type Message struct {
	ID      int64
	Topic   string
	Payload []byte
}

func New(db *sql.DB) *Outbox { return &Outbox{db: db} }

func (o *Outbox) Insert(ctx context.Context, tx *sql.Tx, topic string, payload []byte) error {
	_, err := tx.ExecContext(ctx,
		`INSERT INTO outbox (topic, payload, state) VALUES ($1, $2, 'pending')`, topic, payload)
	return err
}

func (o *Outbox) Claim(ctx context.Context, topic string, n int) ([]Message, error) {
	rows, err := o.db.QueryContext(ctx,
		`UPDATE outbox SET state = 'claimed', claimed_at = now()
		 WHERE id IN (SELECT id FROM outbox WHERE topic = $1 AND state = 'pending'
		              ORDER BY id LIMIT $2 FOR UPDATE SKIP LOCKED)
		 RETURNING id, topic, payload`, topic, n)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Message
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.ID, &m.Topic, &m.Payload); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (o *Outbox) Done(ctx context.Context, id int64) error {
	_, err := o.db.ExecContext(ctx, `UPDATE outbox SET state = 'done' WHERE id = $1`, id)
	return err
}

func (o *Outbox) Release(ctx context.Context, id int64) error {
	_, err := o.db.ExecContext(ctx, `UPDATE outbox SET state = 'pending' WHERE id = $1`, id)
	return err
}
