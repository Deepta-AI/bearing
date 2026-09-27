// Package notify tells a merchant that something they asked for is ready.
package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Notifier sends merchant notifications.
type Notifier interface {
	ExportReady(ctx context.Context, accountID int64, rows int) error
}

// Webhook posts notifications to the merchant messaging service.
type Webhook struct {
	URL    string
	Client *http.Client
}

// New returns the webhook for url. Notifications are optional: with url
// empty it returns nil and the API runs without them.
func New(url string) *Webhook {
	if url == "" {
		return nil
	}
	return &Webhook{URL: url, Client: &http.Client{Timeout: 5 * time.Second}}
}

// ExportReady implements Notifier.
func (w *Webhook) ExportReady(ctx context.Context, accountID int64, rows int) error {
	body, err := json.Marshal(map[string]any{"event": "export_ready", "account_id": accountID, "rows": rows})
	if err != nil {
		return fmt.Errorf("encode export notification: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, w.URL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build export notification: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := w.Client.Do(req)
	if err != nil {
		return fmt.Errorf("send export notification: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		return fmt.Errorf("send export notification: %s", res.Status)
	}
	return nil
}
