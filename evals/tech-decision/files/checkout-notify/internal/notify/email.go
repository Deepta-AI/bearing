package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"time"
)

// Email sends through Postmark.
type Email struct {
	token  string
	client *http.Client
}

func NewEmail(token string) *Email {
	return &Email{token: token, client: &http.Client{Timeout: 5 * time.Second}}
}

func (e *Email) Send(ctx context.Context, to, subject, body string) error {
	payload, _ := json.Marshal(map[string]string{
		"From": "orders@shop.example", "To": to, "Subject": subject, "TextBody": body,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.postmarkapp.com/email", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("X-Postmark-Server-Token", e.token)
	resp, err := e.client.Do(req)
	if err != nil {
		return err
	}
	return resp.Body.Close()
}
