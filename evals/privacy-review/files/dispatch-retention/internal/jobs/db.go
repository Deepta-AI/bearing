// Package jobs holds the one-shot worker jobs run by deploy/cronjobs.yaml.
package jobs

import "context"

// Execer is the slice of *sql.DB (or pgx) the jobs need.
type Execer interface {
	Exec(ctx context.Context, query string, args ...any) (int64, error)
}
