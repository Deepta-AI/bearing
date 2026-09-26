package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func get(t *testing.T, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	Routes(SampleStore()).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestV1ItemsPriceInRupees(t *testing.T) {
	rec := get(t, "/v1/orders/ord_1001/items")
	var body struct {
		Items []struct {
			Qty   int     `json:"qty"`
			Price float64 `json:"price"`
		} `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || len(body.Items) != 1 {
		t.Fatalf("items: %v %s", err, rec.Body)
	}
	if body.Items[0].Price != 349.50 || body.Items[0].Qty != 2 {
		t.Fatalf("got %+v", body.Items[0])
	}
}

func TestV2EmbedsLines(t *testing.T) {
	rec := get(t, "/v2/orders/ord_1001")
	var body struct {
		Lines []struct {
			Quantity       int   `json:"quantity"`
			UnitPriceMinor int64 `json:"unit_price_minor"`
		} `json:"lines"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || len(body.Lines) != 1 {
		t.Fatalf("lines: %v %s", err, rec.Body)
	}
	if body.Lines[0].UnitPriceMinor != 34950 {
		t.Fatalf("got %+v", body.Lines[0])
	}
}
