package sms

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"time"
)

// maxRequestsPerSecond is the MSG91 plan limit on our contract.
const maxRequestsPerSecond = 20

// ErrRateLimited is returned when MSG91 answers 429. The caller decides
// whether to retry; this client never does.
var ErrRateLimited = errors.New("sms: rate limited by provider")

type Client struct {
	BaseURL  string
	APIKey   string
	SenderID string
	HTTP     *http.Client
	tick     <-chan time.Time
}

// FromEnv builds a client from SMS_API_KEY and SMS_SENDER_ID.
func FromEnv() (*Client, error) {
	key := os.Getenv("SMS_API_KEY")
	if key == "" {
		return nil, errors.New("sms: SMS_API_KEY is not set")
	}
	return New("https://control.msg91.com/api/v5", key, os.Getenv("SMS_SENDER_ID")), nil
}

func New(baseURL, key, sender string) *Client {
	return &Client{
		BaseURL:  baseURL,
		APIKey:   key,
		SenderID: sender,
		HTTP:     &http.Client{Timeout: 5 * time.Second},
		tick:     time.Tick(time.Second / maxRequestsPerSecond),
	}
}

// Send sends one text message to one phone number, waiting for the
// client-side rate limiter first.
func (c *Client) Send(ctx context.Context, phone, text string) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-c.tick:
	}
	body, _ := json.Marshal(map[string]string{"sender": c.SenderID, "mobiles": phone, "message": text})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+"/flow/", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("authkey", c.APIKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusTooManyRequests:
		return ErrRateLimited
	case resp.StatusCode >= 300:
		return fmt.Errorf("sms: provider status %d", resp.StatusCode)
	}
	return nil
}
