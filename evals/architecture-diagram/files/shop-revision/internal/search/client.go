package search

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// Client talks to Meilisearch's products index.
type Client struct {
	base string
	http *http.Client
}

func NewClient(base string) *Client {
	return &Client{base: base, http: &http.Client{Timeout: 5 * time.Second}}
}

func (c *Client) Upsert(ctx context.Context, doc []byte) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut,
		c.base+"/indexes/products/documents", bytes.NewReader(append(append([]byte("["), doc...), ']')))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("upsert: status %d", resp.StatusCode)
	}
	return nil
}

func (c *Client) Query(ctx context.Context, q string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		c.base+"/indexes/products/search?q="+url.QueryEscape(q), nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}
