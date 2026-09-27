package api

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeTrack struct{}

func (fakeTrack) DeliveriesForPhone(_ context.Context, phone string) ([]Delivery, error) {
	if phone == "9876543210" {
		return []Delivery{{ID: 7, Status: "out_for_delivery"}}, nil
	}
	return nil, nil
}

func TestTrack(t *testing.T) {
	h := AccessLog(Track(fakeTrack{}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/track?phone=9876543210", nil))
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "out_for_delivery") {
		t.Fatalf("got %d %s", rec.Code, rec.Body.String())
	}
}
