// Command worker runs one job and exits: `worker <job>`.
package main

import (
	"context"
	"database/sql"
	"log"
	"os"
	"time"

	"example.com/dispatch/internal/jobs"
)

type sqlExecer struct{ db *sql.DB }

func (s sqlExecer) Exec(ctx context.Context, q string, args ...any) (int64, error) {
	res, err := s.db.ExecContext(ctx, q, args...)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("usage: worker <job>")
	}
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	ctx := context.Background()
	ex := sqlExecer{db}

	switch name := os.Args[1]; name {
	case "stale-deliveries":
		if _, err := jobs.MarkStaleDeliveries(ctx, ex, time.Now()); err != nil {
			log.Fatal(err)
		}
	case "purge-location-pings":
		if _, err := jobs.PurgePings(ctx, ex, time.Now()); err != nil {
			log.Fatal(err)
		}
	default:
		log.Printf("unknown job %q, nothing to do", name)
	}
}
