package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/orders/internal/store"
)

func TestGetOrder(t *testing.T) {
	s := store.Demo()
	cases := []struct {
		name   string
		id     string
		status int
		body   string
	}{
		{"found", "ord_1001", http.StatusOK, ""},
		{"missing", "ord_404", http.StatusNotFound, "not_found"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest(http.MethodGet, "/v1/orders/"+tc.id, nil)
			r.SetPathValue("id", tc.id)
			w := httptest.NewRecorder()
			GetOrder(s)(w, r)
			if w.Code != tc.status {
				t.Fatalf("status %d, want %d", w.Code, tc.status)
			}
			if tc.body != "" {
				var got map[string]string
				_ = json.Unmarshal(w.Body.Bytes(), &got)
				if got["error"] != tc.body {
					t.Fatalf("error %q, want %q", got["error"], tc.body)
				}
			}
		})
	}
}

func TestExportOrders(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/v1/orders/export/csv", nil)
	r.SetPathValue("format", "csv")
	w := httptest.NewRecorder()
	ExportOrders(store.Demo())(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d, want 200", w.Code)
	}
	lines := strings.Split(strings.TrimSpace(w.Body.String()), "\n")
	if len(lines) != 3 || lines[1] != "ord_1001,cus_7,paid,149900" {
		t.Fatalf("csv %q", w.Body.String())
	}
}
