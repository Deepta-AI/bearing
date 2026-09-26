// Package payments calls the payments provider.
package payments

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"
)

// ErrDeclined means the provider refused the charge.
var ErrDeclined = errors.New("payments: declined")

// Client charges orders through the provider's HTTP API.
type Client struct {
	baseURL string
	http    *http.Client
}

// New returns a client with a 3 s timeout that retries once on a
// connection error or a 503.
func New(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		http: &http.Client{
			Timeout:   3 * time.Second,
			Transport: &retryTransport{base: http.DefaultTransport, attempts: 2},
		},
	}
}

type chargeRequest struct {
	OrderID     string `json:"order_id"`
	AmountCents int64  `json:"amount_cents"`
}

type chargeResponse struct {
	ChargeID string `json:"charge_id"`
	Status   string `json:"status"`
}

// Charge charges the order and returns the provider's charge id.
func (c *Client) Charge(orderID string, amountCents int64) (string, error) {
	body, _ := json.Marshal(chargeRequest{OrderID: orderID, AmountCents: amountCents})
	req, err := http.NewRequest(http.MethodPost, c.baseURL+"/v1/charges", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Idempotency-Key", "order-"+orderID)
	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("payments: charge %s: %w", orderID, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusPaymentRequired {
		return "", ErrDeclined
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("payments: charge %s: status %d", orderID, resp.StatusCode)
	}
	var out chargeResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", fmt.Errorf("payments: decode: %w", err)
	}
	return out.ChargeID, nil
}

type retryTransport struct {
	base     http.RoundTripper
	attempts int
}

func (t *retryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	var body []byte
	if req.Body != nil {
		body, _ = readAll(req)
	}
	var resp *http.Response
	var err error
	for i := 0; i < t.attempts; i++ {
		r := req.Clone(req.Context())
		if body != nil {
			r.Body = nopCloser(body)
		}
		resp, err = t.base.RoundTrip(r)
		if err == nil && resp.StatusCode != http.StatusServiceUnavailable {
			return resp, nil
		}
		if err == nil && i < t.attempts-1 {
			resp.Body.Close()
		}
	}
	return resp, err
}
