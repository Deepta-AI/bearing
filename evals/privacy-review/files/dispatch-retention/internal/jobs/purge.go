package jobs

import (
	"context"
	"log/slog"
	"time"
)

// PingRetentionDays is how long rider location pings are kept
// (docs/privacy/retention.md).
const PingRetentionDays = 90

// PingCutoff is the oldest ping time that is kept at now.
func PingCutoff(now time.Time) time.Time {
	return now.AddDate(0, 0, -PingRetentionDays)
}

// PurgePings deletes rider location pings older than the retention window.
func PurgePings(ctx context.Context, db Execer, now time.Time) (int64, error) {
	n, err := db.Exec(ctx, `DELETE FROM location_pings WHERE at < $1`, PingCutoff(now))
	if err != nil {
		return 0, err
	}
	slog.Info("purged location pings", "rows", n)
	return n, nil
}
