package notify

import (
	"context"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// SMS sends through MSG91's HTTP API.
type SMS struct {
	key    string
	client *http.Client
}

func NewSMS(key string) *SMS {
	return &SMS{key: key, client: &http.Client{Timeout: 5 * time.Second}}
}

func (s *SMS) Send(ctx context.Context, phone, text string) error {
	form := url.Values{"mobiles": {phone}, "message": {text}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.msg91.com/api/v2/sendsms", strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("authkey", s.key)
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	return resp.Body.Close()
}
