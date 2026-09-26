package webhooks

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"example.com/parcelpost/internal/shipments"
)

type countingNotifier struct{ sent int }

func (n *countingNotifier) SendDelivered(ctx context.Context, email, id string) error {
	n.sent++
	return nil
}

const testSecret = "whsec_test_only"

func sign(ts int64, body string) string {
	mac := hmac.New(sha256.New, []byte(testSecret))
	fmt.Fprintf(mac, "%d.%s", ts, body)
	return fmt.Sprintf("t=%d,v1=%s", ts, hex.EncodeToString(mac.Sum(nil)))
}

func TestDeliveredSendsEmail(t *testing.T) {
	n := &countingNotifier{}
	svc := shipments.NewService(n, shipments.Shipment{ID: "shp_1042", Email: "asha@example.in"})
	h := &Dispatchly{Secret: []byte(testSecret), Shipments: svc}

	body := `{"id":"evt_8Kq2mX","type":"shipment.delivered","created":1758612000,"data":{"shipment_id":"shp_1042","status":"delivered","occurred_at":"2026-09-23T07:20:00Z"}}`
	req := httptest.NewRequest(http.MethodPost, "/webhooks/dispatchly", strings.NewReader(body))
	req.Header.Set("Dispatchly-Signature", sign(time.Now().Unix(), body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK || n.sent != 1 {
		t.Fatalf("status %d, emails %d", rec.Code, n.sent)
	}
}
