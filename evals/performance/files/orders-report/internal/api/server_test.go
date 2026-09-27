package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/orders-api/internal/report"
	"example.com/orders-api/internal/store"
)

func TestReportEndpoint(t *testing.T) {
	s := store.New()
	store.Seed(s, 50, 10, 1)
	srv := httptest.NewServer(NewMux(s))
	defer srv.Close()

	res, err := http.Get(srv.URL + "/reports/orders?status=paid")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d", res.StatusCode)
	}
	var rows []report.Row
	if err := json.NewDecoder(res.Body).Decode(&rows); err != nil {
		t.Fatal(err)
	}
	if len(rows) == 0 {
		t.Fatal("no rows")
	}
}

func TestReportRejectsUnknownStatus(t *testing.T) {
	srv := httptest.NewServer(NewMux(store.New()))
	defer srv.Close()
	res, err := http.Get(srv.URL + "/reports/orders?status=lost")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", res.StatusCode)
	}
}

func TestCreateOrder(t *testing.T) {
	srv := httptest.NewServer(NewMux(store.New()))
	defer srv.Close()
	body := `{"id":"ord_x","customer_id":"cus_1","status":"paid","created_at":"2026-08-01T10:00:00Z","items":[]}`
	res, err := http.Post(srv.URL+"/orders", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("status %d, want 201", res.StatusCode)
	}
}
