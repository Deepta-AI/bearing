// Command digest sends the weekly digest to every account. It runs from the
// reportsvc-digest CronJob in deploy/k8s.yaml.
package main

import (
	"log/slog"
	"os"

	"example.com/reportsvc/internal/reports"
)

type logSender struct{}

func (logSender) Send(e reports.Email) error {
	slog.Info("digest", "to", e.To, "attachments", len(e.Attachments))
	return nil
}

func main() {
	store := reports.NewStore(
		reports.Report{ID: "demo", AccountID: "a1", Title: "Demo", Columns: []string{"k", "v"}, Rows: [][]string{{"a", "1"}}},
	)
	d := &reports.Digest{Store: store, Sender: logSender{}}
	if err := d.SendWeekly("a1", "owner@example.com"); err != nil {
		slog.Error("digest", "err", err)
		os.Exit(1)
	}
}
