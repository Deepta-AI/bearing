// Package inventory reserves stock in the warehouse inventory service
// before an order is placed.
package inventory

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	base string
	http *http.Client
}

func NewClient(base string) *Client {
	return &Client{base: base, http: &http.Client{Timeout: 3 * time.Second}}
}

// Reserve holds the cart's items for 15 minutes.
func (c *Client) Reserve(ctx context.Context, cartID string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.base+"/reservations", strings.NewReader(fmt.Sprintf(`{"cart_id":%q,"ttl_seconds":900}`, cartID)))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("reserve: status %d", resp.StatusCode)
	}
	return nil
}
