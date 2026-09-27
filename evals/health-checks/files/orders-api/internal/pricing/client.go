// Package pricing calls pricing-api for line price quotes.
package pricing

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Client struct {
	base string
	http *http.Client
}

func New(base string, timeout time.Duration) *Client {
	return &Client{base: base, http: &http.Client{Timeout: timeout}}
}

type Quote struct {
	SKU        string `json:"sku"`
	PriceCents int64  `json:"price_cents"`
}

func (c *Client) Quote(ctx context.Context, sku string) (Quote, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.base+"/v1/quotes/"+sku, nil)
	if err != nil {
		return Quote{}, err
	}
	res, err := c.http.Do(req)
	if err != nil {
		return Quote{}, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return Quote{}, fmt.Errorf("pricing: %s returned %d", sku, res.StatusCode)
	}
	var q Quote
	return q, json.NewDecoder(res.Body).Decode(&q)
}
