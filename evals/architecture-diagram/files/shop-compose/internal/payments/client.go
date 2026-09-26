package payments

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// Client captures authorised Razorpay payments.
type Client struct {
	base string
	http *http.Client
}

func NewClient(base string) *Client {
	return &Client{base: base, http: &http.Client{Timeout: 10 * time.Second}}
}

func (c *Client) Capture(ctx context.Context, paymentID string, amountPaise int64) error {
	return c.post(ctx, "/payments/"+paymentID+"/capture", fmt.Sprintf(`{"amount":%d,"currency":"INR"}`, amountPaise))
}

// Refund returns a captured payment in full.
func (c *Client) Refund(ctx context.Context, paymentID string, amountPaise int64) error {
	return c.post(ctx, "/payments/"+paymentID+"/refund", fmt.Sprintf(`{"amount":%d}`, amountPaise))
}

func (c *Client) post(ctx context.Context, path, body string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base+path, strings.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: status %d", path, resp.StatusCode)
	}
	return nil
}
