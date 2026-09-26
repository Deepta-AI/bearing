package billing

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func testStore() *Store {
	return NewStore([]Client{
		{ID: "c_2", Name: "B", Plan: "pro", Active: true, MonthlyPaise: 249900},
		{ID: "c_1", Name: "A", Plan: "basic", Active: true, MonthlyPaise: 49900},
		{ID: "c_3", Name: "C", Plan: "basic", Active: false, MonthlyPaise: 49900},
	})
}

func TestStoreClient(t *testing.T) {
	c, err := testStore().Client("c_1")
	if err != nil || c.Name != "A" {
		t.Fatalf("got %+v, %v", c, err)
	}
	if _, err := testStore().Client("nope"); !errors.Is(err, ErrClientNotFound) {
		t.Fatalf("want ErrClientNotFound, got %v", err)
	}
}

func TestActiveClientsSorted(t *testing.T) {
	got := testStore().ActiveClients()
	if len(got) != 2 || got[0].ID != "c_1" || got[1].ID != "c_2" {
		t.Fatalf("got %+v", got)
	}
}

func TestChargeMonthlySendsClientID(t *testing.T) {
	var seen map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(b, &seen)
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()
	c, _ := testStore().Client("c_2")
	if err := NewCharger(srv.URL).ChargeMonthly(context.Background(), c); err != nil {
		t.Fatal(err)
	}
	if seen["client_id"] != "c_2" || seen["amount_paise"] != float64(249900) {
		t.Fatalf("gateway got %v", seen)
	}
}
