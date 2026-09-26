// Package analytics sends product events. Here it logs them; the collector
// ships the log lines to the pipeline.
package analytics

import (
	"context"
	"log/slog"
)

// Track records one event with its properties.
func Track(ctx context.Context, event string, props map[string]string) {
	args := []any{"event", event}
	for k, v := range props {
		args = append(args, k, v)
	}
	slog.InfoContext(ctx, "analytics", args...)
}
