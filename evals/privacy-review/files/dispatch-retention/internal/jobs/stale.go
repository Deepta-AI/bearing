package jobs

import (
	"context"
	"log/slog"
	"time"
)

// MarkStaleDeliveries flags bookings nobody picked up within two hours.
func MarkStaleDeliveries(ctx context.Context, db Execer, now time.Time) (int64, error) {
	n, err := db.Exec(ctx,
		`UPDATE deliveries SET status = 'stale' WHERE status = 'booked' AND created_at < $1`,
		now.Add(-2*time.Hour))
	if err != nil {
		return 0, err
	}
	slog.Info("marked stale deliveries", "rows", n)
	return n, nil
}
