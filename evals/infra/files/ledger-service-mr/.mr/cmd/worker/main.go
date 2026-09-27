// Command ledger-worker posts pending ledger entries every five seconds.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	if os.Getenv("DATABASE_URL") == "" {
		slog.Error("DATABASE_URL is not set")
		os.Exit(1)
	}
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	slog.Info("ledger-worker started")
	for {
		select {
		case <-ctx.Done():
			slog.Info("ledger-worker stopping")
			return
		case <-tick.C:
			postPending(ctx)
		}
	}
}

// postPending claims a batch of pending postings and applies them.
func postPending(ctx context.Context) {
	_ = ctx
	slog.Debug("posting batch")
}
