package orders

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCreateRejectsEmptyBasket(t *testing.T) {
	h := NewHandler(NewMemoryStore())
	rec := httptest.NewRecorder()
	h.Create(rec, httptest.NewRequest("POST", "/v1/orders", strings.NewReader(`{"email":"a@example.com","items":[]}`)))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
}

func TestCreateThenGet(t *testing.T) {
	h := NewHandler(NewMemoryStore())
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/orders", h.Create)
	mux.HandleFunc("GET /v1/orders/{id}", h.Get)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("POST", "/v1/orders", strings.NewReader(`{"email":"a@example.com","items":[{"sku":"SKU-0001","qty":2,"price_paise":50900}]}`)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("create status %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"total_paise":101800`) {
		t.Fatalf("total wrong: %s", rec.Body.String())
	}
	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/v1/orders/ord_1", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("get status %d", rec.Code)
	}
}
