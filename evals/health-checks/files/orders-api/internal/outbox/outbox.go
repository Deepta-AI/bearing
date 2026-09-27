// Package outbox writes order events in the order's own transaction
// (ADR-0003). The data team's CDC connector reads the table.
package outbox

import (
	"context"
	"database/sql"
	"encoding/json"
)

func Write(ctx context.Context, tx *sql.Tx, kind string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO outbox (kind, payload) VALUES ($1, $2)`, kind, b)
	return err
}
