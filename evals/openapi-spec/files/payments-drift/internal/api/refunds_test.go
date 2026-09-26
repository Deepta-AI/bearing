package api

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func post(t *testing.T, h http.Handler, path, key, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestPartialRefunds(t *testing.T) {
	h := NewServer(NewMemoryStore()).Routes()
	rec := post(t, h, "/v1/payments", "", `{"amount_minor":10000,"currency":"INR","customer_id":"cus_1"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create payment: %d %s", rec.Code, rec.Body)
	}
	if got := post(t, h, "/v1/payments/pay_000001/refunds", "k1", `{"amount_minor":4000}`).Code; got != http.StatusCreated {
		t.Fatalf("first refund: %d", got)
	}
	if got := post(t, h, "/v1/payments/pay_000001/refunds", "k1", `{"amount_minor":4000}`).Code; got != http.StatusCreated {
		t.Fatalf("replayed refund: %d", got)
	}
	if got := post(t, h, "/v1/payments/pay_000001/refunds", "k2", `{"amount_minor":7000}`).Code; got != http.StatusUnprocessableEntity {
		t.Fatalf("over refund: %d", got)
	}
	if got := post(t, h, "/v1/payments/pay_000001/refunds", "", `{"amount_minor":100}`).Code; got != http.StatusBadRequest {
		t.Fatalf("missing key: %d", got)
	}
}
