// Package notify tells the ERP that an invoice was issued.
package notify

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"mods.example.com/retry"
)

// Issued posts the invoice id to the ERP webhook, retrying transient
// failures.
func Issued(ctx context.Context, client *http.Client, url, invoiceID string) error {
	return retry.Do(ctx, 4, 200*time.Millisecond, func() error {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url+"?invoice="+invoiceID, nil)
		if err != nil {
			return err
		}
		resp, err := client.Do(req)
		if err != nil {
			return err
		}
		resp.Body.Close()
		if resp.StatusCode >= 500 {
			return fmt.Errorf("erp returned %d", resp.StatusCode)
		}
		return nil
	})
}
