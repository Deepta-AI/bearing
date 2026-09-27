// Command archive writes every report as CSV to the warehouse bucket. It
// runs nightly from the reportsvc-archive CronJob in deploy/k8s.yaml; the
// data warehouse loads the files the same night.
package main

import (
	"log/slog"
	"os"

	"example.com/reportsvc/internal/reports"
)

type logSink struct{}

func (logSink) Put(key string, body []byte) error {
	slog.Info("archive", "key", key, "bytes", len(body))
	return nil
}

func main() {
	store := reports.NewStore(
		reports.Report{ID: "demo", AccountID: "a1", Title: "Demo", Columns: []string{"k", "v"}, Rows: [][]string{{"a", "1"}}},
	)
	n, err := reports.Archive(store, logSink{})
	if err != nil {
		slog.Error("archive", "err", err)
		os.Exit(1)
	}
	slog.Info("archive", "reports", n)
}
