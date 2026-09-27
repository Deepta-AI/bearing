package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/shipments-api/internal/store"
)

func fixture() http.Handler {
	return NewHandler(store.NewMemory(
		store.Shipment{ID: "s1", Status: "in_transit", Carrier: store.Carrier{Code: "BLD", Name: "Bluedart"}},
		store.Shipment{ID: "s2", Status: "delivered", Carrier: store.Carrier{Code: "DLV", Name: "Delhivery"}},
		store.Shipment{ID: "s3", Status: "in_transit", Carrier: store.Carrier{Code: "BLD", Name: "Bluedart"}},
	))
}

func get(t *testing.T, h http.Handler, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestListFiltersByStatus(t *testing.T) {
	rec := get(t, fixture(), "/v1/shipments?status=in_transit")
	var body struct{ Shipments []store.Shipment }
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if len(body.Shipments) != 2 {
		t.Fatalf("got %d shipments, want 2", len(body.Shipments))
	}
}

func TestShipmentCarrierIsNested(t *testing.T) {
	rec := get(t, fixture(), "/v1/shipments/s2")
	var body map[string]any
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	c, ok := body["carrier"].(map[string]any)
	if !ok || c["code"] != "DLV" {
		t.Fatalf("carrier = %v", body["carrier"])
	}
}

func TestUnknownShipmentIs404(t *testing.T) {
	if rec := get(t, fixture(), "/v1/shipments/nope"); rec.Code != http.StatusNotFound {
		t.Fatalf("status %d, want 404", rec.Code)
	}
}

func TestBadLimitIs400(t *testing.T) {
	if rec := get(t, fixture(), "/v1/shipments?limit=zero"); rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
}
