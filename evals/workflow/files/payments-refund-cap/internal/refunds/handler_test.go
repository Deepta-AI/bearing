package refunds

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func serve(s Store, id, body string) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.Handle("POST /payments/{id}/refunds", NewHandler(s))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/payments/"+id+"/refunds", strings.NewReader(body))
	mux.ServeHTTP(rec, req)
	return rec
}

func TestRefundCreated(t *testing.T) {
	s := NewMemStore(Payment{ID: "pay_1", Captured: 50000})
	rec := serve(s, "pay_1", `{"amount": 20000}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201", rec.Code)
	}
	p, _ := s.Get("pay_1")
	if p.Refunded != 20000 {
		t.Fatalf("refunded = %d, want 20000", p.Refunded)
	}
}

func TestRefundRejectsZero(t *testing.T) {
	s := NewMemStore(Payment{ID: "pay_1", Captured: 50000})
	if rec := serve(s, "pay_1", `{"amount": 0}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestRefundUnknownPayment(t *testing.T) {
	s := NewMemStore()
	if rec := serve(s, "pay_x", `{"amount": 100}`); rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
}
