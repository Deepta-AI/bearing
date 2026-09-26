package refunds

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

var testNow = time.Date(2026, 9, 1, 10, 0, 0, 0, time.UTC)

type nopPublisher struct{}

func (nopPublisher) Publish(string, any) error { return nil }

func newTestServer(t *testing.T, orders ...Order) http.Handler {
	t.Helper()
	store := NewStore()
	for _, o := range orders {
		store.PutOrder(o)
	}
	mux := http.NewServeMux()
	Routes(mux, NewService(store, nopPublisher{}, func() time.Time { return testNow }))
	return mux
}

func do(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("error body is not JSON: %v", err)
	}
	return body.Error
}

func capturedOrder(id string, totalPaise int64) Order {
	return Order{ID: id, TotalPaise: totalPaise, Status: "captured", CapturedAt: testNow.Add(-24 * time.Hour)}
}

func TestTC0101_FullRefundOfCapturedOrder(t *testing.T) {
	h := newTestServer(t, capturedOrder("ord_1", 100000))

	rec := do(t, h, http.MethodPost, "/orders/ord_1/refunds", `{"amount_paise":100000}`)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201; body %s", rec.Code, rec.Body)
	}
	var ref Refund
	if err := json.Unmarshal(rec.Body.Bytes(), &ref); err != nil {
		t.Fatal(err)
	}
	if ref.AmountPaise != 100000 || ref.OrderID != "ord_1" {
		t.Fatalf("refund = %+v, want ord_1 for 100000 paise", ref)
	}
}

func TestTC0102_RefundOfUncapturedOrder(t *testing.T) {
	h := newTestServer(t, Order{ID: "ord_2", TotalPaise: 50000, Status: "authorized"})

	rec := do(t, h, http.MethodPost, "/orders/ord_2/refunds", `{"amount_paise":10000}`)

	if rec.Code != http.StatusConflict || errorCode(t, rec) != "order_not_captured" {
		t.Fatalf("got %d %s, want 409 order_not_captured", rec.Code, rec.Body)
	}
}

func TestTC0105_InvalidAmountRejected(t *testing.T) {
	h := newTestServer(t, capturedOrder("ord_1", 100000))

	rec := do(t, h, http.MethodPost, "/orders/ord_1/refunds", `{"amount_paise":-10000}`)

	if rec.Code != http.StatusUnprocessableEntity || errorCode(t, rec) != "invalid_amount" {
		t.Fatalf("got %d %s, want 422 invalid_amount", rec.Code, rec.Body)
	}
}
