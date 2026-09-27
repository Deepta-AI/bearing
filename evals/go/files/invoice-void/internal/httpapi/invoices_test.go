package httpapi

import (
	"encoding/json"
	"net/http"
	"testing"
)

func TestListInvoices(t *testing.T) {
	ts, _ := newTestServer(t)
	tests := []struct {
		name    string
		query   string
		key     string
		status  int
		wantIDs []int64
	}{
		{name: "all of account a, newest first", query: "", key: "key-a", status: 200, wantIDs: []int64{3, 2, 1}},
		{name: "open only", query: "?status=open", key: "key-a", status: 200, wantIDs: []int64{1}},
		{name: "none match is an empty array", query: "?status=paid", key: "key-b", status: 200, wantIDs: []int64{}},
		{name: "unknown status", query: "?status=late", key: "key-a", status: 400},
		{name: "no key", query: "", key: "", status: 401},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := do(t, ts, "GET", "/invoices"+tc.query, tc.key, "")
			if res.StatusCode != tc.status {
				t.Fatalf("status = %d, want %d", res.StatusCode, tc.status)
			}
			if tc.status != 200 {
				return
			}
			var body struct {
				Items []struct {
					ID int64 `json:"id"`
				} `json:"items"`
			}
			if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
				t.Fatal(err)
			}
			if body.Items == nil {
				t.Fatal("items is null, want an array")
			}
			got := make([]int64, 0, len(body.Items))
			for _, it := range body.Items {
				got = append(got, it.ID)
			}
			if len(got) != len(tc.wantIDs) {
				t.Fatalf("ids = %v, want %v", got, tc.wantIDs)
			}
			for i := range got {
				if got[i] != tc.wantIDs[i] {
					t.Fatalf("ids = %v, want %v", got, tc.wantIDs)
				}
			}
		})
	}
}

func TestGetInvoiceOfAnotherAccountIsNotFound(t *testing.T) {
	ts, _ := newTestServer(t)
	if res := do(t, ts, "GET", "/invoices/4", "key-a", ""); res.StatusCode != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", res.StatusCode)
	}
}

func TestPayInvoice(t *testing.T) {
	ts, repo := newTestServer(t)
	res := do(t, ts, "POST", "/invoices/1/pay", "key-a", "")
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.StatusCode)
	}
	if got := repo.invs[1].Status; got != "paid" {
		t.Fatalf("status = %s, want paid", got)
	}
}
