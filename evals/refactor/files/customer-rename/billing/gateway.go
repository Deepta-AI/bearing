package billing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// gatewayClient talks to the card gateway over HTTPS.
type gatewayClient struct {
	baseURL string
	http    *http.Client
}

func newGatewayClient(baseURL string) *gatewayClient {
	return &gatewayClient{baseURL: baseURL, http: &http.Client{Timeout: 10 * time.Second}}
}

type chargeRequest struct {
	ClientID    string `json:"client_id"`
	AmountPaise int64  `json:"amount_paise"`
}

// Charger charges a client's monthly amount through the gateway.
type Charger struct {
	gw *gatewayClient
}

// NewCharger returns a Charger for the gateway at baseURL.
func NewCharger(baseURL string) *Charger {
	return &Charger{gw: newGatewayClient(baseURL)}
}

// ChargeMonthly charges one month for the client.
func (c *Charger) ChargeMonthly(ctx context.Context, client Client) error {
	body, err := json.Marshal(chargeRequest{ClientID: client.ID, AmountPaise: client.MonthlyPaise})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.gw.baseURL+"/charges", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.gw.http.Do(req)
	if err != nil {
		return fmt.Errorf("charge %s: %w", client.ID, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("charge %s: gateway status %d", client.ID, resp.StatusCode)
	}
	return nil
}
