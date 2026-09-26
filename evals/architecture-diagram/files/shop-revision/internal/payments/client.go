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
	body := strings.NewReader(fmt.Sprintf(`{"amount":%d,"currency":"INR"}`, amountPaise))
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.base+"/payments/"+paymentID+"/capture", body)
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
		return fmt.Errorf("capture: status %d", resp.StatusCode)
	}
	return nil
}
