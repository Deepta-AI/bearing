package jobs

import (
	"context"
	"database/sql"
	"log"
	"time"
)

const (
	// batchSize and pollInterval together cap the worker at 10 jobs a second.
	batchSize    = 50
	pollInterval = 5 * time.Second
)

// Handler runs one job. A returned error marks the job failed.
type Handler func(ctx context.Context, payload []byte) error

type Worker struct {
	DB       *sql.DB
	Handlers map[string]Handler // keyed by jobs.kind
}

// Run polls for due jobs until ctx is done. Only one worker process runs
// in each environment today.
func (w *Worker) Run(ctx context.Context) {
	t := time.NewTicker(pollInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			w.runBatch(ctx)
		}
	}
}

func (w *Worker) runBatch(ctx context.Context) {
	rows, err := w.DB.QueryContext(ctx,
		`SELECT id, kind, payload FROM jobs
		 WHERE status = 'pending' AND run_at <= now()
		 ORDER BY run_at LIMIT $1`, batchSize)
	if err != nil {
		log.Printf("jobs: poll failed: %v", err)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var id int64
		var kind string
		var payload []byte
		if err := rows.Scan(&id, &kind, &payload); err != nil {
			log.Printf("jobs: scan: %v", err)
			continue
		}
		status := "done"
		if h, ok := w.Handlers[kind]; !ok {
			status = "failed"
		} else if err := h(ctx, payload); err != nil {
			log.Printf("jobs: %s %d failed: %v", kind, id, err)
			status = "failed"
		}
		w.DB.ExecContext(ctx,
			`UPDATE jobs SET status = $2, attempts = attempts + 1, updated_at = now() WHERE id = $1`,
			id, status)
	}
}
